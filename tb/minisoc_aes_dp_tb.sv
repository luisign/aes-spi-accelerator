module minisoc_aes_dp_tb;

  localparam int N_VEC = 12;
  localparam int N_STREAM = 8;
  localparam int KEY_LAT = 10;
  localparam int BLOCK_LAT = 10;
  localparam int STREAM_SPACING = 11;
  localparam int TIMEOUT_CYCLES = 50000;

  // DUT e geracao do sinal de clock:
  logic clk;
  logic rst_n;
  logic [127:0] key;
  logic key_load;
  logic key_ready;
  logic [127:0] din;
  logic dec;
  logic start;
  logic busy;
  logic done;
  logic [127:0] dout;

  minisoc_aes_dp dut (
    .clk (clk),
    .rst_n (rst_n),
    .key_i (key),
    .key_load_i (key_load),
    .key_ready_o (key_ready),
    .data_i (din),
    .decrypt_i (dec),
    .start_i (start),
    .busy_o (busy),
    .done_o (done),
    .data_o (dout)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Vetores:
  logic [127:0] vec_key [N_VEC];
  logic [127:0] vec_pt [N_VEC];
  logic [127:0] vec_ct [N_VEC];

  // Fluxo de blocos para a chave vec_key[STREAM_KEY]:
  localparam int STREAM_KEY = 3;
  logic [127:0] st_in [N_STREAM];
  logic st_dec [N_STREAM];
  logic [127:0] st_exp [N_STREAM];

  initial begin
    vec_key[0] = 128'h2b7e151628aed2a6abf7158809cf4f3c; vec_pt[0] = 128'h3243f6a8885a308d313198a2e0370734; vec_ct[0] = 128'h3925841d02dc09fbdc118597196a0b32;
    vec_key[1] = 128'h000102030405060708090a0b0c0d0e0f; vec_pt[1] = 128'h00112233445566778899aabbccddeeff; vec_ct[1] = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
    vec_key[2] = 128'h5b0942ba04ea21433018c81a389c0f99; vec_pt[2] = 128'hff079bde8518f9c9aa90445424b6f6c9; vec_ct[2] = 128'hd284304962e92d1b65de587a601396e6;
    vec_key[3] = 128'h8acaa019e1d5b4ee32928c0d00505340; vec_pt[3] = 128'h26f2be496fc5a27b6ad6a62f2e507fde; vec_ct[3] = 128'h3074db2aacde676acb523922058cb028;
    vec_key[4] = 128'h2046090358d04568f89f1b9d006dc9b7; vec_pt[4] = 128'hbe189f35d5775243b37f176825a66c42; vec_ct[4] = 128'hde8316178b1873b846ac5fd2f4c90eeb;
    vec_key[5] = 128'hd251ae26c87a0a88226994b9ff9a745c; vec_pt[5] = 128'hc918a2f1435133209bdbb33a5413e7fe; vec_ct[5] = 128'hb8dcf982fd07a64c3c11a1883db7e033;
    vec_key[6] = 128'h1ef954294f805fd23fdd4da90c2d3507; vec_pt[6] = 128'h2e919b66756943c38659a29df835fd4a; vec_ct[6] = 128'h2cd4aa3d2b913c41f532f7fcea7478b3;
    vec_key[7] = 128'hc5d19122658a5403342244ce180cccaa; vec_pt[7] = 128'h6fba5819b28243ced2ad6503dd0aa81a; vec_ct[7] = 128'hb89055a37ead63d8831c95030b05dd50;
    vec_key[8] = 128'haf5e6b36260862b5ffb15343b40f2aa6; vec_pt[8] = 128'he1a54a307538967cda495dbdfd997b9c; vec_ct[8] = 128'h96036b3b3d53c8552693af3dbcda4b5a;
    vec_key[9] = 128'h9155a4a2d0dd40c9ee2d75110b2b06b5; vec_pt[9] = 128'h1113cd99ba9277aeb97264fd03032cb3; vec_ct[9] = 128'h1ec5f1f6e50f38e83ab6e409a53e20e6;
    vec_key[10] = 128'hed9e48cdafea45e78f0d2dc0ea900cab; vec_pt[10] = 128'hbeb28ce5d6b0a97d26c180e4bcf60174; vec_ct[10] = 128'h1fd6b945104393626ef8eee552c25c62;
    vec_key[11] = 128'h274c775371c22e50d922930a0cf1899e; vec_pt[11] = 128'h8e72ccd64a866c7d9131cbb2410657b2; vec_ct[11] = 128'hf06f01bcf052c8a01462848b7edf8ad3;
    st_in[0] = 128'h660392534e44ab7a1031f5f587496399; st_dec[0] = 1'b0; st_exp[0] = 128'h4b496700f0a9ac663372f749ba0a330d;
    st_in[1] = 128'h4b496700f0a9ac663372f749ba0a330d; st_dec[1] = 1'b1; st_exp[1] = 128'h660392534e44ab7a1031f5f587496399;
    st_in[2] = 128'h321de9633010a41a991f00d627180248; st_dec[2] = 1'b0; st_exp[2] = 128'h52396d2b7e7dbb0c180104626b94fe8e;
    st_in[3] = 128'h52396d2b7e7dbb0c180104626b94fe8e; st_dec[3] = 1'b1; st_exp[3] = 128'h321de9633010a41a991f00d627180248;
    st_in[4] = 128'hd0c3c2690214cc59a9c818cea952df1b; st_dec[4] = 1'b0; st_exp[4] = 128'h1b53b4a3b8f63b981b9510421334b695;
    st_in[5] = 128'h1b53b4a3b8f63b981b9510421334b695; st_dec[5] = 1'b1; st_exp[5] = 128'hd0c3c2690214cc59a9c818cea952df1b;
    st_in[6] = 128'hf6a4d0aca574bab5ed6511a7d6c48e54; st_dec[6] = 1'b0; st_exp[6] = 128'h33dafbcda5e1ed1b17f262a922671820;
    st_in[7] = 128'h33dafbcda5e1ed1b17f262a922671820; st_dec[7] = 1'b1; st_exp[7] = 128'hf6a4d0aca574bab5ed6511a7d6c48e54;
  end

  // Contadores e utilitarios de verificacao:
  int errors;
  int checks;

  task automatic check1(input string name, input logic got, input logic exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[FAIL] %s: obtido=%b esperado=%b", name, got, exp);
    end
  endtask

  task automatic check_int(input string name, input int got, input int exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[FAIL] %s: obtido=%0d esperado=%0d", name, got, exp);
    end
  endtask

  task automatic check128(input string name, input logic [127:0] got, input logic [127:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[FAIL] %s:\n obtido  =%032h\n esperado=%032h", name, got, exp);
    end
  endtask

  // busy_o e done_o nao pode ser 1 ao mesmo tempo:
  always @(negedge clk) begin
    if (rst_n && busy === 1'b1 && done === 1'b1) begin
      errors++;
      $error("[FAIL] busy_o e done_o em 1 no mesmo ciclo");
    end
  end

  // Espera n bordas de descida do clock:
  task automatic cycles(input int n);
    repeat (n) @(negedge clk);
  endtask

  // Pulso de key_load_i de 1 ciclo e espera key_ready_o e devolve os ciclos contados:
  task automatic load_key(input logic [127:0] k, output int n);
    @(negedge clk);
    key = k;
    key_load = 1'b1;
    @(negedge clk);
    key_load = 1'b0;
    n = 0;
    while (!key_ready && n < 40) begin
      @(negedge clk);
      n++;
    end
  endtask

  // Conta os ciclos ate done_o subir, vendo se busy_o fica em 1 enquanto isso:
  task automatic wait_done(output int n);
    n = 0;
    while (!done && n < 40) begin
      check1("busy_o durante a operacao", busy, 1'b1);
      @(negedge clk);
      n++;
    end
  endtask

  // start_i, espera done_o, confere o comportamento de busy/done:
  task automatic run_block(
    input logic [127:0] d, 
    input logic decr,
    output logic [127:0] res,
    output int n);
    
    @(negedge clk);
    din = d;
    dec = decr;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    din = ~d;
    dec = ~decr;
    wait_done(n);
    check1("busy_o cai junto com done_o", busy, 1'b0);
    res = dout;
    @(negedge clk);
    check1("done_o dura 1 ciclo", done, 1'b0);
    check128("data_o estavel apos o done_o", dout, res);
  endtask

  // Watchdog para evitar que a simulacao trave:
  initial begin
    repeat (TIMEOUT_CYCLES) @(posedge clk);
    $display("FAIL: watchdog - simulacao excedeu %0d ciclos", TIMEOUT_CYCLES);
    $fatal(1, "minisoc_aes_dp_tb: watchdog");
  end

  // Estimulos:
  int e0;
  int n;
  int n2;
  logic [127:0] r;

  initial begin
    errors = 0;
    checks = 0;
    rst_n = 1'b0;
    key = '0;
    key_load = 1'b0;
    din = '0;
    dec = 1'b0;
    start = 1'b0;

    // Reset inicial:
    cycles(3);
    rst_n = 1'b1;
    cycles(2);
    e0 = errors;
    check1("apos reset: busy_o", busy, 1'b0);
    check1("apos reset: done_o", done, 1'b0);
    check1("apos reset: key_ready_o", key_ready, 1'b0);
    $display("[INFO] (1) Estado apos o reset: %0d erro(s)", errors - e0);

    // Cifrando e decifrando 12 vetores:
    e0 = errors;
    for (int v = 0; v < N_VEC; v++) begin
      if (v > 0) check1($sformatf("vetor %0d: key_ready antes do load", v), key_ready, 1'b1);
      load_key(vec_key[v], n);
      check_int($sformatf("vetor %0d: latencia de key_ready", v), n, KEY_LAT);

      run_block(vec_pt[v], 1'b0, r, n);
      check128($sformatf("vetor %0d: cifrar", v), r, vec_ct[v]);
      check_int($sformatf("vetor %0d: latencia (cifra)", v), n, BLOCK_LAT);

      run_block(vec_ct[v], 1'b1, r, n);
      check128($sformatf("vetor %0d: decifrar", v), r, vec_pt[v]);
      check_int($sformatf("vetor %0d: latencia (decifra)", v), n, BLOCK_LAT);
    end
    $display("[INFO] (2) %0d vetores, cifra e decifra (FIPS-197 e aleatorios): %0d erro(s)",
             N_VEC, errors - e0);

    // start_i sem key_ready_o e ignorado:
    e0 = errors;
    @(negedge clk);
    key = vec_key[4];
    key_load = 1'b1;
    @(negedge clk);
    key_load = 1'b0;
    din = vec_pt[4];
    dec = 1'b0;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    check1("start sem key_ready: key_ready ainda em 0", key_ready, 1'b0);
    cycles(3);
    check1("start sem key_ready: busy_o", busy, 1'b0);
    check1("start sem key_ready: done_o", done, 1'b0);
    n = 0;
    while (!key_ready && n < 40) begin
      @(negedge clk);
      n++;
    end
    cycles(15);
    check1("start sem key_ready: nenhuma operacao disparou (busy_o)", busy, 1'b0);
    check1("start sem key_ready: nenhuma operacao disparou (done_o)", done, 1'b0);
    run_block(vec_pt[4], 1'b0, r, n);
    check128("apos start ignorado: cifrar", r, vec_ct[4]);
    $display("[INFO] (3) start_i sem chave pronta: %0d erro(s)", errors - e0);

    // start_i e key_load_i durante busy_o sao ignorados:
    e0 = errors;
    @(negedge clk);
    din = vec_pt[4];
    dec = 1'b0;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    cycles(2);
    din = vec_ct[0];
    dec = 1'b1;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    cycles(1);
    key = vec_key[0];
    key_load = 1'b1;
    @(negedge clk);
    key_load = 1'b0;
    wait_done(n);
    check128("busy: resultado do primeiro start", dout, vec_ct[4]);
    check1("busy: key_ready segue em 1", key_ready, 1'b1);
    run_block(vec_ct[4], 1'b1, r, n);
    check128("busy: chave original preservada (decifrar)", r, vec_pt[4]);
    $display("[INFO] (4) start_i e key_load_i durante busy: %0d erro(s)", errors - e0);

    // Fluxo de 8 blocos, start_i no ciclo do done_o:
    e0 = errors;
    load_key(vec_key[STREAM_KEY], n);
    check_int("fluxo: latencia de key_ready", n, KEY_LAT);
    @(negedge clk);
    din = st_in[0];
    dec = st_dec[0];
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    for (int i = 0; i < N_STREAM; i++) begin
      wait_done(n);
      if (i == 0) check_int("fluxo: latencia do 1o bloco", n, BLOCK_LAT);
      else check_int($sformatf("fluxo: espacamento entre done_o (bloco %0d)", i), n, STREAM_SPACING - 1);
      check128($sformatf("fluxo: bloco %0d", i), dout, st_exp[i]);
      if (i < N_STREAM - 1) begin
        din = st_in[i + 1];
        dec = st_dec[i + 1];
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        check1($sformatf("fluxo: start no ciclo do done_o aceito (bloco %0d)", i + 1), busy, 1'b1);
      end
    end
    cycles(3);
    $display("[INFO] (5) Fluxo de %0d blocos seguidos: %0d erro(s)", N_STREAM, errors - e0);

    // Reset no meio de uma operacao:
    e0 = errors;
    @(negedge clk);
    din = vec_pt[STREAM_KEY];
    dec = 1'b0;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    cycles(4);
    check1("reset no meio: busy_o antes do reset", busy, 1'b1);
    rst_n = 1'b0;
    cycles(2);
    check1("reset no meio: busy_o", busy, 1'b0);
    check1("reset no meio: done_o", done, 1'b0);
    check1("reset no meio: key_ready_o", key_ready, 1'b0);
    rst_n = 1'b1;
    @(negedge clk);
    din = vec_pt[STREAM_KEY];
    dec = 1'b0;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    cycles(3);
    check1("reset no meio: start sem chave ignorado (busy_o)", busy, 1'b0);
    load_key(vec_key[STREAM_KEY], n);
    run_block(vec_pt[STREAM_KEY], 1'b0, r, n);
    check128("apos reset: cifrar", r, vec_ct[STREAM_KEY]);
    run_block(vec_ct[STREAM_KEY], 1'b1, r, n);
    check128("apos reset: decifrar", r, vec_pt[STREAM_KEY]);
    $display("[INFO] (6) Reset no meio de uma operacao: %0d erro(s)", errors - e0);

    // Resultado final:
    $display("--------------------------------------------------");
    if (errors == 0) begin
      $display("PASS: %0d verificacoes, 0 erros", checks);
      $finish;
    end else begin
      $display("FAIL: %0d verificacoes, %0d erro(s)", checks, errors);
      $fatal(1, "minisoc_aes_dp_tb falhou");
    end
  end

endmodule
