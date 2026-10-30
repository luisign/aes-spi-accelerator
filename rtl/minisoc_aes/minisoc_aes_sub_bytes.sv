module minisoc_aes_sub_bytes (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  genvar n;
  generate
    for (n = 0; n < 16; n++) begin : g_sbox
      minisoc_aes_sbox u_sbox (
        .data_i (state_i[127 - 8*n -: 8]),
        .data_o (state_o[127 - 8*n -: 8])
      );
    end
  endgenerate

endmodule
