module minisoc_aes_inv_mix_columns (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  function automatic logic [7:0] xtime(input logic [7:0] a);
    return {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
  endfunction

  function automatic logic [7:0] mul09(input logic [7:0] a);
    return xtime(xtime(xtime(a))) ^ a;
  endfunction

  function automatic logic [7:0] mul0b(input logic [7:0] a);
    return xtime(xtime(xtime(a))) ^ xtime(a) ^ a;
  endfunction

  function automatic logic [7:0] mul0d(input logic [7:0] a);
    return xtime(xtime(xtime(a))) ^ xtime(xtime(a)) ^ a;
  endfunction

  function automatic logic [7:0] mul0e(input logic [7:0] a);
    return xtime(xtime(xtime(a))) ^ xtime(xtime(a)) ^ xtime(a);
  endfunction

  genvar c;
  generate
    for (c = 0; c < 4; c++) begin : g_col
      logic [7:0] s0, s1, s2, s3;
      logic [7:0] m0, m1, m2, m3;

      assign s0 = state_i[127 - 8*(4*c + 0) -: 8];
      assign s1 = state_i[127 - 8*(4*c + 1) -: 8];
      assign s2 = state_i[127 - 8*(4*c + 2) -: 8];
      assign s3 = state_i[127 - 8*(4*c + 3) -: 8];

      assign m0 = mul0e(s0) ^ mul0b(s1) ^ mul0d(s2) ^ mul09(s3);
      assign m1 = mul09(s0) ^ mul0e(s1) ^ mul0b(s2) ^ mul0d(s3);
      assign m2 = mul0d(s0) ^ mul09(s1) ^ mul0e(s2) ^ mul0b(s3);
      assign m3 = mul0b(s0) ^ mul0d(s1) ^ mul09(s2) ^ mul0e(s3);

      assign state_o[127 - 8*(4*c + 0) -: 8] = m0;
      assign state_o[127 - 8*(4*c + 1) -: 8] = m1;
      assign state_o[127 - 8*(4*c + 2) -: 8] = m2;
      assign state_o[127 - 8*(4*c + 3) -: 8] = m3;
    end
  endgenerate

endmodule
