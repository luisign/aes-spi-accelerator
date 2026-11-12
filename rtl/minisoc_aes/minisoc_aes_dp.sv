module minisoc_aes_dp (
  input logic clk,
  input logic rst_n,

  // Chave:
  input logic [127:0] key_i,
  input logic key_load_i,
  output logic key_ready_o,

  // Bloco:
  input logic [127:0] data_i,
  input logic decrypt_i,
  input logic start_i,
  output logic busy_o,
  output logic done_o,
  output logic [127:0] data_o
);

  // Estado do controle e do datapath:
  logic [127:0] state_q;
  logic [3:0] round_q;
  logic dec_q;
  logic busy_q;
  logic done_q;

  logic start_ok;
  logic last_round;

  assign start_ok = start_i && key_ready_o && !busy_q;
  assign last_round = (round_q == 4'd10);

  // Chaves de rodada:
  logic [3:0] rk_sel;
  logic [127:0] rk;
  logic key_load;

  assign key_load = key_load_i && !busy_q;

  // Rodada r: cifra usa rk[r]; decifra usa rk[10-r],
  // Carga (start_i): cifra usa rk[0]; decifra usa rk[10]:
  assign rk_sel = busy_q ? (dec_q ? (4'd10 - round_q) : round_q) : (decrypt_i ? 4'd10 : 4'd0);

  minisoc_aes_key_exp u_key_exp (
    .clk (clk),
    .rst_n (rst_n),
    .key_i (key_i),
    .key_load_i (key_load),
    .key_ready_o (key_ready_o),
    .rk_sel_i (rk_sel),
    .rk_o (rk)
  );


  // Carga: operacao AddRoundKey:

  logic [127:0] load_state;

  minisoc_aes_add_round_key u_ark_load (
    .state_i (data_i),
    .round_key_i (rk),
    .state_o (load_state)
  );


  // Bloco de rodada: path da cifragem:

  logic [127:0] sb_out, sr_out, mc_out;

  minisoc_aes_sub_bytes u_sub_bytes (.state_i(state_q), .state_o(sb_out));
  minisoc_aes_shift_rows u_shift_rows (.state_i(sb_out), .state_o(sr_out));
  minisoc_aes_mix_columns u_mix_columns (.state_i(sr_out), .state_o(mc_out));


  // Bloco de rodada: path de decifragem:

  logic [127:0] isr_out, isb_out, imc_out;
  logic [127:0] ark_in, ark_out;

  minisoc_aes_inv_shift_rows u_inv_shift_rows (.state_i(state_q), .state_o(isr_out));
  minisoc_aes_inv_sub_bytes u_inv_sub_bytes (.state_i(isr_out), .state_o(isb_out));

  // AddRoundKey da rodada compartilhado entre cifra e decifra:
  assign ark_in = dec_q ? isb_out : (last_round ? sr_out : mc_out);

  minisoc_aes_add_round_key u_ark_round (
    .state_i (ark_in),
    .round_key_i (rk),
    .state_o (ark_out)
  );

  minisoc_aes_inv_mix_columns u_inv_mix_columns (.state_i(ark_out), .state_o(imc_out));

  // Resultado da rodada:
  logic [127:0] round_state;
  assign round_state = dec_q ? (last_round ? ark_out : imc_out) : ark_out;

  // Registradores:
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= '0;
      round_q <= 4'd0;
      dec_q <= 1'b0;
      busy_q <= 1'b0;
      done_q <= 1'b0;
    end else begin
      done_q <= 1'b0;

      if (start_ok) begin
        state_q <= load_state;
        round_q <= 4'd1;
        dec_q <= decrypt_i;
        busy_q <= 1'b1;
      end else if (busy_q) begin
        state_q <= round_state;
        if (last_round) begin
          busy_q <= 1'b0;
          done_q <= 1'b1;
        end else begin
          round_q <= round_q + 4'd1;
        end
      end
    end
  end

  // Saidas do modulo:
  assign busy_o = busy_q;
  assign done_o = done_q;
  assign data_o = state_q;

endmodule
