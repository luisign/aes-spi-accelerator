module minisoc_aes_key_exp (
  input logic clk,
  input logic rst_n,

  input logic [127:0] key_i,
  input logic key_load_i,
  output logic key_ready_o,

  input logic [3:0] rk_sel_i,
  output logic [127:0] rk_o
);

  // Estado:
  logic [127:0] rk_q [11];
  logic [3:0] cnt_q;
  logic expanding_q;
  logic ready_q;

  // Constante de rodada, rodadas 1 a 10:
  function automatic logic [7:0] rcon(input logic [3:0] idx);
    case (idx)
      4'd1: return 8'h01;
      4'd2: return 8'h02;
      4'd3: return 8'h04;
      4'd4: return 8'h08;
      4'd5: return 8'h10;
      4'd6: return 8'h20;
      4'd7: return 8'h40;
      4'd8: return 8'h80;
      4'd9: return 8'h1b;
      4'd10: return 8'h36;
      default: return 8'h00;
    endcase
  endfunction

  // Calculo combinacional da proxima chave de rodada:
  logic [127:0] prev_key;
  logic [31:0] rot_word;
  logic [31:0] sub_word;
  logic [31:0] n0, n1, n2, n3;
  logic [127:0] next_key;

  assign prev_key = (cnt_q >= 4'd1 && cnt_q <= 4'd10) ? rk_q[cnt_q - 4'd1] : '0;

  assign rot_word = {prev_key[23:0], prev_key[31:24]};

  genvar b;
  generate
    for (b = 0; b < 4; b++) begin : g_sub_word
      minisoc_aes_sbox u_sbox (
        .data_i (rot_word[8*b +: 8]),
        .data_o (sub_word[8*b +: 8])
      );
    end
  endgenerate

  assign n0 = prev_key[127:96] ^ sub_word ^ {rcon(cnt_q), 24'h000000};
  assign n1 = prev_key[95:64] ^ n0;
  assign n2 = prev_key[63:32] ^ n1;
  assign n3 = prev_key[31:0] ^ n2;

  assign next_key = {n0, n1, n2, n3};

  // Controle: contador, expansao em andamento e chaves prontas:
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt_q <= 4'd0;
      expanding_q <= 1'b0;
      ready_q <= 1'b0;
    end else if (key_load_i) begin
      // Nova chave: reinicia a expansao:
      cnt_q <= 4'd1;
      expanding_q <= 1'b1;
      ready_q <= 1'b0;
    end else if (expanding_q) begin
      if (cnt_q == 4'd10) begin
        expanding_q <= 1'b0;
        ready_q <= 1'b1;
      end else begin
        cnt_q <= cnt_q + 4'd1;
      end
    end
  end

  // Armazenamento das chaves de rodada:
  always_ff @(posedge clk) begin
    if (key_load_i) begin
      rk_q[0] <= key_i;
    end else if (expanding_q) begin
      rk_q[cnt_q] <= next_key;
    end
  end

  // Saidas:
  assign key_ready_o = ready_q;
  assign rk_o = (ready_q && rk_sel_i <= 4'd10) ? rk_q[rk_sel_i] : '0;

endmodule
