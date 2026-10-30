module minisoc_aes_shift_rows (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  genvar r, c;
  generate
    for (c = 0; c < 4; c++) begin : g_col
      for (r = 0; r < 4; r++) begin : g_row
        assign state_o[127 - 8*(r + 4*c) -: 8] =
               state_i[127 - 8*(r + 4*((c + r) % 4)) -: 8];
      end
    end
  endgenerate

endmodule
