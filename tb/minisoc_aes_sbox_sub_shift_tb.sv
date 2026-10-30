module minisoc_aes_sbox_sub_shift_tb;

  // DUTs:
  logic [7:0] sbox_in;
  logic [7:0] sbox_out;

  logic [127:0] sb_in;
  logic [127:0] sb_out;

  logic [127:0] sr_in;
  logic [127:0] sr_out;

  minisoc_aes_sbox u_sbox (.data_i(sbox_in), .data_o(sbox_out));
  minisoc_aes_sub_bytes u_sub (.state_i(sb_in), .state_o(sb_out));
  minisoc_aes_shift_rows u_shift (.state_i(sr_in), .state_o(sr_out));

  // Modelo de referencia da S-box:
  // Multiplicacao em GF(2^8), polinomio irredutivel x^8+x^4+x^3+x+1 (0x11B):
  function automatic logic [7:0] gf_mul(input logic [7:0] a_i, input logic [7:0] b_i);
    logic [7:0] a, b, r;
    a = a_i;
    b = b_i;
    r = 8'h00;
    for (int k = 0; k < 8; k++) begin
      if (b[0]) r = r ^ a;
      if (a[7]) a = (a << 1) ^ 8'h1B;
      else a = (a << 1);
      b = b >> 1;
    end
    return r;
  endfunction

  // Inverso multiplicativo por forca bruta, 0 -> 0:
  function automatic logic [7:0] gf_inv(input logic [7:0] a);
    logic [7:0] res;
    res = 8'h00;
    if (a != 8'h00) begin
      for (int x = 1; x < 256; x++) begin
        if (gf_mul(a, x[7:0]) == 8'h01) res = x[7:0];
      end
    end
    return res;
  endfunction

  function automatic logic [7:0] rotl8(input logic [7:0] v, input int n);
    return (v << n) | (v >> (8 - n));
  endfunction

  // Inverso + transformacao afim:
  function automatic logic [7:0] sbox_ref(input logic [7:0] x);
    logic [7:0] b;
    b = gf_inv(x);
    return b ^ rotl8(b, 1) ^ rotl8(b, 2) ^ rotl8(b, 3) ^ rotl8(b, 4) ^ 8'h63;
  endfunction

  // Vetores da FIPS-197:
  logic [127:0] vec_start [10];
  logic [127:0] vec_sub [10];
  logic [127:0] vec_shift [10];

  initial begin
    vec_start[0] = 128'h193de3bea0f4e22b9ac68d2ae9f84808; vec_sub[0] = 128'hd42711aee0bf98f1b8b45de51e415230; vec_shift[0] = 128'hd4bf5d30e0b452aeb84111f11e2798e5;
    vec_start[1] = 128'ha49c7ff2689f352b6b5bea43026a5049; vec_sub[1] = 128'h49ded28945db96f17f39871a7702533b; vec_shift[1] = 128'h49db873b453953897f02d2f177de961a;
    vec_start[2] = 128'haa8f5f0361dde3ef82d24ad26832469a; vec_sub[2] = 128'hac73cf7befc111df13b5d6b545235ab8; vec_shift[2] = 128'hacc1d6b8efb55a7b1323cfdf457311b5;
    vec_start[3] = 128'h486c4eee671d9d0d4de3b138d65f58e7; vec_sub[3] = 128'h52502f2885a45ed7e311c807f6cf6a94; vec_shift[3] = 128'h52a4c89485116a28e3cf2fd7f6505e07;
    vec_start[4] = 128'he0927fe8c86363c0d9b1355085b8be01; vec_sub[4] = 128'he14fd29be8fbfbba35c89653976cae7c; vec_shift[4] = 128'he1fb967ce8c8ae9b356cd2ba974ffb53;
    vec_start[5] = 128'hf1006f55c1924cef7cc88b325db5d50c; vec_sub[5] = 128'ha163a8fc784f29df10e83d234cd503fe; vec_shift[5] = 128'ha14f3dfe78e803fc10d5a8df4c632923;
    vec_start[6] = 128'h260e2e173d41b77de86472a9fdd28b25; vec_sub[6] = 128'hf7ab31f02783a9ff9b4340d354b53d3f; vec_shift[6] = 128'hf783403f27433df09bb531ff54aba9d3;
    vec_start[7] = 128'h5a4142b11949dc1fa3e019657a8c040c; vec_sub[7] = 128'hbe832cc8d43b86c00ae1d44dda64f2fe; vec_shift[7] = 128'hbe3bd4fed4e1f2c80a642cc0da83864d;
    vec_start[8] = 128'hea835cf00445332d655d98ad8596b0c5; vec_sub[8] = 128'h87ec4a8cf26ec3d84d4c46959790e7a6; vec_shift[8] = 128'h876e46a6f24ce78c4d904ad897ecc395;
    vec_start[9] = 128'heb40f21e592e38848ba113e71bc342d2; vec_sub[9] = 128'he9098972cb31075f3d327d94af2e2cb5; vec_shift[9] = 128'he9317db5cb322c723d2e895faf090794;
  end

  // Contadores:
  int errors;
  int checks;

  task automatic check8(input string name, input logic [7:0] got, input logic [7:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[FAIL] %s: obtido=%02h esperado=%02h", name, got, exp);
    end
  endtask

  task automatic check128(input string name, input logic [127:0] got, input logic [127:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[FAIL] %s:\n obtido=%032h\n esperado=%032h", name, got, exp);
    end
  endtask

  // Estimulos:
  
  int sbox_errors_start;
  int sub_errors_start;
  int shift_errors_start;

  initial begin
    errors = 0;
    checks = 0;
    sbox_in = '0;
    sb_in = '0;
    sr_in = '0;
    #1;

    sbox_errors_start = errors;
    for (int i = 0; i < 256; i++) begin
      sbox_in = i[7:0];
      #1;
      check8($sformatf("sbox(%02h)", i[7:0]), sbox_out, sbox_ref(i[7:0]));
    end

    sbox_in = 8'h00; #1; check8("sbox(00) FIPS-197", sbox_out, 8'h63);
    sbox_in = 8'h53; #1; check8("sbox(53) FIPS-197", sbox_out, 8'hed);
    $display("[INFO] S-box (256 entradas + 2 valores FIPS-197): %0d erro(s)",
             errors - sbox_errors_start);

    // SubBytes: start of round -> after SubBytes:
    sub_errors_start = errors;
    for (int r = 0; r < 10; r++) begin
      sb_in = vec_start[r];
      #1;
      check128($sformatf("SubBytes rodada %0d", r + 1), sb_out, vec_sub[r]);
    end
    $display("[INFO] SubBytes (rodadas 1 a 10): %0d erro(s)", errors - sub_errors_start);

    // ShiftRows: after SubBytes -> after ShiftRows:
    shift_errors_start = errors;
    for (int r = 0; r < 10; r++) begin
      sr_in = vec_sub[r];
      #1;
      check128($sformatf("ShiftRows rodada %0d", r + 1), sr_out, vec_shift[r]);
    end
    $display("[INFO] ShiftRows (rodadas 1 a 10): %0d erro(s)", errors - shift_errors_start);

    // Resultado final:
    $display("--------------------------------------------------");
    if (errors == 0) begin
      $display("PASS: %0d verificacoes, 0 erros", checks);
      $finish;
    end else begin
      $display("FAIL: %0d verificacoes, %0d erro(s)", checks, errors);
      $fatal(1, "minisoc_aes_sbox_sub_shift_tb falhou");
    end
  end

endmodule
