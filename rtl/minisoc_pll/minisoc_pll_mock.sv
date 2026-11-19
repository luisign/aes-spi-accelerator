module minisoc_pll_mock #(
  parameter int LOCK_MIN_CYCLES = 16,
  parameter int LOCK_RAND_BITS = 5
) (
  input logic clk_ref_i, // referencia de 2 GHz (clk do MiniSoC)
  input logic rst_n,

  input logic enable_i, // PLL_ENABLE
  input logic [1:0] div_sel_i, // PLL_DIV_SEL

  output logic locked_o, // PLL_LOCKED
  output logic sys_clk_o // clock de sistema
);

  // LFSR de 16 bits (x^16 + x^14 + x^13 + x^11 + 1), livre, com semente fixa:
  logic [15:0] lfsr_q;
  logic [15:0] lock_delay;

  always_ff @(posedge clk_ref_i or negedge rst_n) begin
    if (!rst_n) begin
      lfsr_q <= 16'hACE1;
    end else begin
      lfsr_q <= {lfsr_q[14:0], lfsr_q[15] ^ lfsr_q[13] ^ lfsr_q[12] ^ lfsr_q[10]};
    end
  end

  assign lock_delay = 16'(LOCK_MIN_CYCLES) + (lfsr_q & ((16'd1 << LOCK_RAND_BITS) - 16'd1));

  // Divisor de clock: contador livre, e o bit k-1 tem frequencia clk_ref / 2^k:
  logic [2:0] div_cnt_q;
  logic [1:0] div_sel_q; // divisor em uso (so muda com o clock bloqueado)
  logic clk_div; // clock dividido selecionado
  logic en_lat; // habilitacao do clock (latch de clock gating)

  always_ff @(posedge clk_ref_i or negedge rst_n) begin
    if (!rst_n) div_cnt_q <= 3'd0;
    else div_cnt_q <= div_cnt_q + 3'd1;
  end

  always_comb begin
    case (div_sel_q)
      2'b00: clk_div = clk_ref_i; // /1
      2'b01: clk_div = div_cnt_q[0]; // /2
      2'b10: clk_div = div_cnt_q[1]; // /4
      default: clk_div = div_cnt_q[2]; // /8
    endcase
  end

  // Aquisicao do lock:
  typedef enum logic [1:0] {S_OFF, S_ACQ, S_LOCKED} state_e;

  state_e state_q;
  logic locked_q;
  logic [15:0] acq_cnt_q;

  always_ff @(posedge clk_ref_i or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= S_OFF;
      locked_q <= 1'b0;
      div_sel_q <= 2'b00;
      acq_cnt_q <= 16'd0;
    end else if (!enable_i) begin
      // Desabilitado: sem lock e clock bloqueado:
      state_q <= S_OFF;
      locked_q <= 1'b0;
    end else begin
      case (state_q)
        S_OFF: begin
          // So inicia a aquisicao com o clock efetivamente bloqueado (en_lat = 0), para trocar o divisor sem glitch
          if (!en_lat) begin
            div_sel_q <= div_sel_i;
            acq_cnt_q <= lock_delay;
            state_q   <= S_ACQ;
          end
        end

        S_ACQ: begin
          if (div_sel_i != div_sel_q) begin
            div_sel_q <= div_sel_i;
            acq_cnt_q <= lock_delay;
          end else if (acq_cnt_q <= 16'd1) begin
            state_q  <= S_LOCKED;
            locked_q <= 1'b1;
          end else begin
            acq_cnt_q <= acq_cnt_q - 16'd1;
          end
        end

        S_LOCKED: begin
          if (div_sel_i != div_sel_q) begin
            state_q  <= S_OFF;
            locked_q <= 1'b0;
          end
        end

        default: state_q <= S_OFF;
      endcase
    end
  end

  // Clock gating sem glitch: o latch so acompanha locked_q com o clock dividido em nivel baixo, entao o clock so sobe/desce em pulsos completos:
  always_latch begin
    if (!clk_div) en_lat = locked_q;
  end

  assign sys_clk_o = clk_div & en_lat;
  assign locked_o  = locked_q;

endmodule
