module minisoc_aes_top (
  input logic clk, // sys_clk
  input logic rst_n,

  // Configuracao (cfg) e comando:
  input logic [127:0] cfg_key_i,
  input logic [127:0] cfg_iv_i,
  input logic [63:0] cfg_counter_i,
  input logic [31:0] cfg_num_blocks_i,
  input logic [2:0] cfg_mode_i,
  input logic cfg_decrypt_i,
  input logic start_i,

  // Status:
  output logic busy_o,
  output logic done_o,
  output logic error_o,
  output logic [8:0] blocks_done_o,

  // Memoria:
  output logic [9:0] mem_addr_o,
  output logic [31:0] mem_wdata_o,
  output logic mem_we_o,
  input logic [31:0] mem_rdata_i
);

  // Modos e estados:
  localparam logic [2:0] MODE_ECB = 3'b000;
  localparam logic [2:0] MODE_CBC = 3'b001;
  localparam logic [2:0] MODE_CTR = 3'b101;

  typedef enum logic [3:0] {
    S_IDLE,
    S_CHECK,
    S_KEY_LOAD,
    S_KEY_WAIT,
    S_RD,
    S_CORE_START,
    S_CORE_WAIT,
    S_POST,
    S_WR,
    S_FIN,
    S_ERR
  } state_e;

  state_e state_q;

  // Registradores:
  logic [127:0] key_q;
  logic [127:0] chain_q;
  logic [63:0] ctr_q;
  logic [31:0] nblk_q;
  logic [2:0] mode_q;
  logic dec_q;

  logic [127:0] blk_in_q;
  logic [127:0] blk_out_q;
  logic [7:0] blk_idx_q;
  logic [2:0] cnt_q;

  logic busy_q;
  logic done_q;
  logic error_q;
  logic [8:0] blocks_done_q;

  // Nucleo AES (minisoc_aes_dp):
  logic core_key_load;
  logic core_key_ready;
  logic [127:0] core_in;
  logic core_dec;
  logic core_start;
  logic core_busy;
  logic core_done;
  logic [127:0] core_out;

  assign core_key_load = (state_q == S_KEY_LOAD);
  assign core_start = (state_q == S_CORE_START);

  // Entrada e sentido do nucleo pelo modo:
  always_comb begin
    core_in = blk_in_q;
    core_dec = dec_q;
    case (mode_q)
      MODE_CBC: begin
        core_in = dec_q ? blk_in_q : (blk_in_q ^ chain_q);
        core_dec = dec_q;
      end
      MODE_CTR: begin
        core_in = chain_q ^ {64'd0, ctr_q};
        core_dec = 1'b0;
      end
      default: begin
        core_in = blk_in_q;
        core_dec = dec_q;
      end
    endcase
  end

  minisoc_aes_dp u_core (
    .clk (clk),
    .rst_n (rst_n),
    .key_i (key_q),
    .key_load_i (core_key_load),
    .key_ready_o (core_key_ready),
    .data_i (core_in),
    .decrypt_i (core_dec),
    .start_i (core_start),
    .busy_o (core_busy),
    .done_o (core_done),
    .data_o (core_out)
  );

  // Validacao da configuracao (no estado de S_CHECK):
  logic cfg_ok;

  assign cfg_ok = (nblk_q >= 32'd1) && (nblk_q <= 32'd256)
               && (mode_q == MODE_ECB || mode_q == MODE_CBC || mode_q == MODE_CTR);

  // Ultimo bloco da operacao:
  logic last_block;
  assign last_block = ({1'b0, blocks_done_q} + 10'd1) == nblk_q[9:0];

  // Resultado do bloco:
  logic [127:0] blk_out_d;

  always_comb begin
    case (mode_q)
      MODE_CBC: blk_out_d = dec_q ? (core_out ^ chain_q) : core_out;
      MODE_CTR: blk_out_d = blk_in_q ^ core_out;
      default: blk_out_d = core_out;
    endcase
  end

  // FSM e registradores:
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= S_IDLE;
      key_q <= 128'd0;
      chain_q <= 128'd0;
      ctr_q <= 64'd0;
      nblk_q <= 32'd0;
      mode_q <= 3'd0;
      dec_q <= 1'b0;
      blk_in_q <= 128'd0;
      blk_out_q <= 128'd0;
      blk_idx_q <= 8'd0;
      cnt_q <= 3'd0;
      busy_q <= 1'b0;
      done_q <= 1'b0;
      error_q <= 1'b0;
      blocks_done_q <= 9'd0;
    end else begin
      case (state_q)
        // Aguarda o start_i, entao captura a configuracao e limpa o status:
        S_IDLE: begin
          if (start_i) begin
            key_q <= cfg_key_i;
            chain_q <= cfg_iv_i;
            ctr_q <= cfg_counter_i;
            nblk_q <= cfg_num_blocks_i;
            mode_q <= cfg_mode_i;
            dec_q <= cfg_decrypt_i;
            blk_idx_q <= 8'd0;
            blocks_done_q <= 9'd0;
            busy_q <= 1'b1;
            done_q <= 1'b0;
            error_q <= 1'b0;
            state_q <= S_CHECK;
          end
        end

        // Valida MODE e NUM_BLOCKS:
        S_CHECK: begin
          cnt_q <= 3'd0;
          if (cfg_ok) state_q <= S_KEY_LOAD;
          else state_q <= S_ERR;
        end

        // Pulso key_load_i no nucleo:
        S_KEY_LOAD: begin
          state_q <= S_KEY_WAIT;
        end

        // Aguarda a expansao das 11 chaves de rodada:
        S_KEY_WAIT: begin
          cnt_q <= 3'd0;
          if (core_key_ready) state_q <= S_RD;
        end

        // Le 4 palavras: endereco em cnt 0..3, dado visivel em cnt 1..4:
        S_RD: begin
          if (cnt_q >= 3'd1) begin
            blk_in_q[127 - 32 * (cnt_q - 3'd1) -: 32] <= mem_rdata_i;
          end
          if (cnt_q == 3'd4) begin
            cnt_q <= 3'd0;
            state_q <= S_CORE_START;
          end else begin
            cnt_q <= cnt_q + 3'd1;
          end
        end

        // Pulso start_i no nucleo:
        S_CORE_START: begin
          state_q <= S_CORE_WAIT;
        end

        // Aguarda done_o do nucleo:
        S_CORE_WAIT: begin
          if (core_done) state_q <= S_POST;
        end

        // Calcula a saida do bloco e atualiza o encadeamento/contador:
        S_POST: begin
          blk_out_q <= blk_out_d;
          case (mode_q)
            MODE_CBC: chain_q <= dec_q ? blk_in_q : blk_out_d;
            MODE_CTR: ctr_q <= ctr_q + 64'd1;
            default: begin end
          endcase
          cnt_q <= 3'd0;
          state_q <= S_WR;
        end

        // Escreve 4 palavras no mesmo endereco lido:
        S_WR: begin
          if (cnt_q == 3'd3) begin
            blocks_done_q <= blocks_done_q + 9'd1;
            blk_idx_q <= blk_idx_q + 8'd1;
            cnt_q <= 3'd0;
            state_q <= last_block ? S_FIN : S_RD;
          end else begin
            cnt_q <= cnt_q + 3'd1;
          end
        end

        // DONE e BUSY mudam no terceiro ciclo:
        S_FIN: begin
          if (cnt_q == 3'd2) begin
            done_q <= 1'b1;
            busy_q <= 1'b0;
            cnt_q <= 3'd0;
            state_q <= S_IDLE;
          end else begin
            cnt_q <= cnt_q + 3'd1;
          end
        end

        // Configuracao invalida com ERROR no primeiro ciclo e DONE e BUSY no terceiro ciclo:
        S_ERR: begin
          if (cnt_q == 3'd0) error_q <= 1'b1;
          if (cnt_q == 3'd2) begin
            done_q <= 1'b1;
            busy_q <= 1'b0;
            cnt_q <= 3'd0;
            state_q <= S_IDLE;
          end else begin
            cnt_q <= cnt_q + 3'd1;
          end
        end

        default: state_q <= S_IDLE;
      endcase
    end
  end

  // Memoria:
  logic [1:0] word_idx;
  assign word_idx = cnt_q[1:0];

  assign mem_addr_o = {blk_idx_q, word_idx};
  assign mem_we_o = (state_q == S_WR);
  assign mem_wdata_o = blk_out_q[127 - 32 * word_idx -: 32];

  // Saidas de status:
  assign busy_o = busy_q;
  assign done_o = done_q;
  assign error_o = error_q;
  assign blocks_done_o = blocks_done_q;

  logic unused_core_busy;
  assign unused_core_busy = core_busy;

endmodule
