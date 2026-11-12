module minisoc_aes_key_exp_tb;

  localparam int N_VEC = 12;
  localparam int LAT_EXPECTED = 10;
  localparam int TIMEOUT_CYCLES  = 20000;

  // DUT e geracao do sinal de clock:
  logic clk;
  logic rst_n;
  logic [127:0] key;
  logic key_load;
  logic key_ready;
  logic [3:0] sel;
  logic [127:0] rk;

  minisoc_aes_key_exp dut (
    .clk (clk),
    .rst_n (rst_n),
    .key_i (key),
    .key_load_i (key_load),
    .key_ready_o (key_ready),
    .rk_sel_i (sel),
    .rk_o (rk)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Vetores: chaves e chaves de rodada esperadas:
  logic [127:0] vec_key [N_VEC];
  logic [127:0] vec_rk  [N_VEC][11];

  initial begin
    vec_key[0] = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    vec_rk[0][0] = 128'h2b7e151628aed2a6abf7158809cf4f3c; vec_rk[0][1] = 128'ha0fafe1788542cb123a339392a6c7605; vec_rk[0][2] = 128'hf2c295f27a96b9435935807a7359f67f; vec_rk[0][3] = 128'h3d80477d4716fe3e1e237e446d7a883b; vec_rk[0][4] = 128'hef44a541a8525b7fb671253bdb0bad00; vec_rk[0][5] = 128'hd4d1c6f87c839d87caf2b8bc11f915bc;
    vec_rk[0][6] = 128'h6d88a37a110b3efddbf98641ca0093fd; vec_rk[0][7] = 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f; vec_rk[0][8] = 128'head27321b58dbad2312bf5607f8d292f; vec_rk[0][9] = 128'hac7766f319fadc2128d12941575c006e; vec_rk[0][10] = 128'hd014f9a8c9ee2589e13f0cc8b6630ca6;
    vec_key[1] = 128'h000102030405060708090a0b0c0d0e0f;
    vec_rk[1][0] = 128'h000102030405060708090a0b0c0d0e0f; vec_rk[1][1] = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe; vec_rk[1][2] = 128'hb692cf0b643dbdf1be9bc5006830b3fe; vec_rk[1][3] = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41; vec_rk[1][4] = 128'h47f7f7bc95353e03f96c32bcfd058dfd; vec_rk[1][5] = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
    vec_rk[1][6] = 128'h5e390f7df7a69296a7553dc10aa31f6b; vec_rk[1][7] = 128'h14f9701ae35fe28c440adf4d4ea9c026; vec_rk[1][8] = 128'h47438735a41c65b9e016baf4aebf7ad2; vec_rk[1][9] = 128'h549932d1f08557681093ed9cbe2c974e; vec_rk[1][10] = 128'h13111d7fe3944a17f307a78b4d2b30c5;
    vec_key[2] = 128'h5b0942ba04ea21433018c81a389c0f99;
    vec_rk[2][0] = 128'h5b0942ba04ea21433018c81a389c0f99; vec_rk[2][1] = 128'h847facbd80958dfeb08d45e488114a7d; vec_rk[2][2] = 128'h04a95379843cde8734b19b63bca0d11e; vec_rk[2][3] = 128'he097211c64abff9b501a64f8ecbab5e6; vec_rk[2][4] = 128'h1c42afd278e9504928f334b1c4498157; vec_rk[2][5] = 128'h374ef4ce4fa7a48767549036a31d1161;
    vec_rk[2][6] = 128'hb3cc1bc4fc6bbf439b3f2f7538223e14; vec_rk[2][7] = 128'h607ee1c39c155e80072a71f53f084fe1; vec_rk[2][8] = 128'hd0fa19b64cef47364bc536c374cd7922; vec_rk[2][9] = 128'h764c8a243aa3cd127166fbd105ab82f3; vec_rk[2][10] = 128'h225f874f18fc4a5d699ab18c6c31337f;
    vec_key[3] = 128'hff079bde8518f9c9aa90445424b6f6c9;
    vec_rk[3][0] = 128'hff079bde8518f9c9aa90445424b6f6c9; vec_rk[3][1] = 128'hb04546e8355dbf219fcdfb75bb7b0dbc; vec_rk[3][2] = 128'h93922302a6cf9c233902675682796aea; vec_rk[3][3] = 128'h2190a411875f3832be5d5f643c24358e; vec_rk[3][4] = 128'h1f06bdfa985985c82604daac1a20ef22; vec_rk[3][5] = 128'hb8d92e582080ab900684713c1ca49e1e;
    vec_rk[3][6] = 128'hd1d25cc4f152f754f7d68668eb721876; vec_rk[3][7] = 128'hd17f642d202d9379d7fb15113c890d67; vec_rk[3][8] = 128'hf6a8e1c6d68572bf017e67ae3df76ac9; vec_rk[3][9] = 128'h85aa3ce1532f4e5e525129f06fa64339; vec_rk[3][10] = 128'h97b02e49c49f601796ce49e7f9680ade;
    vec_key[4] = 128'h8acaa019e1d5b4ee32928c0d00505340;
    vec_rk[4][0] = 128'h8acaa019e1d5b4ee32928c0d00505340; vec_rk[4][1] = 128'hd827a97a39f21d940b6091990b30c2d9; vec_rk[4][2] = 128'hde029c51e7f081c5ec90105ce7a0d285; vec_rk[4][3] = 128'h3ab70bc5dd478a0031d79a5cd67748d9; vec_rk[4][4] = 128'hc7e53e331aa2b4332b752e6ffd0266b6; vec_rk[4][5] = 128'ha0d67067ba74c4549101ea3b6c038c8d;
    vec_rk[4][6] = 128'hfbb22d3741c6e963d0c70358bcc48fd5; vec_rk[4][7] = 128'ha7c12e52e607c73136c0c4698a044bbc; vec_rk[4][8] = 128'hd5724b2c33758c1d05b548748fb103c8; vec_rk[4][9] = 128'h0609a35f357c2f4230c96736bf7864fe; vec_rk[4][10] = 128'h8c4a1857b936371589ff5023368734dd;
    vec_key[5] = 128'h26f2be496fc5a27b6ad6a62f2e507fde;
    vec_rk[5][0] = 128'h26f2be496fc5a27b6ad6a62f2e507fde; vec_rk[5][1] = 128'h7420a3781be501037133a72c5f63d8f2; vec_rk[5][2] = 128'h8d412ab796a42bb4e7978c98b8f4546a; vec_rk[5][3] = 128'h366128dba0c5036f47528ff7ffa6db9d; vec_rk[5][4] = 128'h1ad876cdba1d75a2fd4ffa5502e921c8; vec_rk[5][5] = 128'h14259ebaae38eb185377114d519e3085;
    vec_rk[5][6] = 128'h3f21096b9119e273c26ef33e93f0c3bb; vec_rk[5][7] = 128'hf30fe3b7621601c4a078f2fa33883141; vec_rk[5][8] = 128'hb7c86074d5de61b075a6934a462ea20b; vec_rk[5][9] = 128'h9df24b2e482c2a9e3d8ab9d47ba41bdf; vec_rk[5][10] = 128'he25dd50faa71ff9197fb4645ec5f5d9a;
    vec_key[6] = 128'h2046090358d04568f89f1b9d006dc9b7;
    vec_rk[6][0] = 128'h2046090358d04568f89f1b9d006dc9b7; vec_rk[6][1] = 128'h1d9ba060454be508bdd4fe95bdb93722; vec_rk[6][2] = 128'h4901331a0c4ad612b19e28870c271fa5; vec_rk[6][3] = 128'h81c135e48d8be3f63c15cb713032d4d4; vec_rk[6][4] = 128'haa897de027029e161b1755672b2581b3; vec_rk[6][5] = 128'h85851011a2878e07b990db6092b55ad3;
    vec_rk[6][6] = 128'h703b765ed2bcf8596b2c2339f99979ea; vec_rk[6][7] = 128'hde8df1c70c31099e671d2aa79e84534d; vec_rk[6][8] = 128'h016012cc0d511b526a4c31f5f4c862b8; vec_rk[6][9] = 128'hf2ca7e73ff9b652195d754d4611f366c; vec_rk[6][10] = 128'h04cf2e9cfb544bbd6e831f690f9c2905;
    vec_key[7] = 128'hbe189f35d5775243b37f176825a66c42;
    vec_rk[7][0] = 128'hbe189f35d5775243b37f176825a66c42; vec_rk[7][1] = 128'h9b48b30a4e3fe149fd40f621d8e69a63; vec_rk[7][2] = 128'h17f0486b59cfa922a48f5f037c69c560; vec_rk[7][3] = 128'hea56987bb399315917166e5a6b7fab3a; vec_rk[7][4] = 128'h3034180483ad295d94bb4707ffc4ec3d; vec_rk[7][5] = 128'h3cfa3f12bf57164f2bec5148d428bd75;
    vec_rk[7][6] = 128'h2880a25a97d7b415bc3be55d68135828; vec_rk[7][7] = 128'h15ea961f823d220a3e06c75756159f7f; vec_rk[7][8] = 128'hcc3144ae4e0c66a4700aa1f3261f3e8c; vec_rk[7][9] = 128'h17832059598f46fd2985e70e0f9ad982; vec_rk[7][10] = 128'h99b6332fc03975d2e9bc92dce6264b5e;
    vec_key[8] = 128'hd251ae26c87a0a88226994b9ff9a745c;
    vec_rk[8][0] = 128'hd251ae26c87a0a88226994b9ff9a745c; vec_rk[8][1] = 128'h6bc3e430a3b9eeb881d07a017e4a0e5d; vec_rk[8][2] = 128'hbf68a8c31cd1467b9d013c7ae34b3227; vec_rk[8][3] = 128'h084b64d2149a22a9899b1ed36ad02cf4; vec_rk[8][4] = 128'h703adbd064a0f979ed3be7aa87ebcb5e; vec_rk[8][5] = 128'h892583c7ed857abe00be9d148755564a;
    vec_rk[8][6] = 128'h559455d0b8112f6eb8afb27a3ffae430; vec_rk[8][7] = 128'h38fd51a580ec7ecb3843ccb107b92881; vec_rk[8][8] = 128'heec95d606e2523ab5666ef1a51dfc79b; vec_rk[8][9] = 128'h6b0f49b1052a6a1a534c85000293429b; vec_rk[8][10] = 128'h81235dc6840937dcd745b2dcd5d6f047;
    vec_key[9] = 128'hc918a2f1435133209bdbb33a5413e7fe;
    vec_rk[9][0] = 128'hc918a2f1435133209bdbb33a5413e7fe; vec_rk[9][1] = 128'hb58c19d1f6dd2af16d0699cb39157e35; vec_rk[9][2] = 128'hee7f8fc318a2a53275a43cf94cb142cc; vec_rk[9][3] = 128'h2253c4ea3af161d84f555d2103e41fed; vec_rk[9][4] = 128'h439391917962f0493637ad6835d3b285; vec_rk[9][5] = 128'h35a406074cc6f64e7af15b264f22e9a3;
    vec_rk[9][6] = 128'h86ba0c83ca7cfacdb08da1ebffaf4848; vec_rk[9][7] = 128'hbfe85e957594a458c51905b33ab64dfb; vec_rk[9][8] = 128'h710b5115049ff54dc186f0fefb30bd05; vec_rk[9][9] = 128'h6e713a1a6aeecf57ab683fa9505882ac; vec_rk[9][10] = 128'h3262ab49588c641ef3e45bb7a3bcd91b;
    vec_key[10] = 128'h1ef954294f805fd23fdd4da90c2d3507;
    vec_rk[10][0] = 128'h1ef954294f805fd23fdd4da90c2d3507; vec_rk[10][1] = 128'hc76f91d788efce05b73283acbb1fb6ab; vec_rk[10][2] = 128'h0521f33d8dce3d383afcbe9481e3083f; vec_rk[10][3] = 128'h101186319ddfbb09a723059d26c00da2; vec_rk[10][4] = 128'ha2c6bcc63f1907cf983a0252befa0ff0; vec_rk[10][5] = 128'h9fb03068a0a937a7389335f586693a05;
    vec_rk[10][6] = 128'h46305b2ce6996c8bde0a597e5863637b; vec_rk[10][7] = 128'hfdcb7a461b5216cdc5584fb39d3b2cc8; vec_rk[10][8] = 128'h9fba921884e884d541b0cb66dc8be7ae; vec_rk[10][9] = 128'hb92e769e3dc6f24b7c76392da0fdde83; vec_rk[10][10] = 128'hdb339a7ee6f568359a8351183a7e8f9b;
    vec_key[11] = 128'h2e919b66756943c38659a29df835fd4a;
    vec_rk[11][0] = 128'h2e919b66756943c38659a29df835fd4a; vec_rk[11][1] = 128'hb9c54d27ccac0ee44af5ac79b2c05133; vec_rk[11][2] = 128'h01148e10cdb880f4874d2c8d358d7dbe; vec_rk[11][3] = 128'h58eb20869553a072121e8cff2793f141; vec_rk[11][4] = 128'h8c4aa34a191903380b078fc72c947e86; vec_rk[11][5] = 128'hbeb9e73ba7a0e403aca76bc480331542;
    vec_rk[11][6] = 128'h5de0cbf6fa402ff556e74431d6d45173; vec_rk[11][7] = 128'h55314400af716bf5f9962fc42f427eb7; vec_rk[11][8] = 128'hf9c2ed1556b386e0af25a9248067d793; vec_rk[11][9] = 128'h67cc31d8317fb7389e5a1e1c1e3dc98f; vec_rk[11][10] = 128'h761142aa476ef592d934eb8ec7092201;
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

  // Espera n bordas de descida do sinal de clock:
  task automatic cycles(input int n);
    repeat (n) @(negedge clk);
  endtask

  // Pulso de key_load_i de 1 ciclo. Ao retornar, vai estar no ciclo seguinte ao pulso:
  task automatic do_load(input logic [127:0] k);
    @(negedge clk);
    key = k;
    key_load = 1'b1;
    @(negedge clk);
    key_load = 1'b0;
  endtask

  // Conta os ciclos ate key_ready_o subir (maximo 30):
  task automatic wait_ready(output int n);
    n = 0;
    while (!key_ready && n < 30) begin
      @(negedge clk);
      n++;
    end
  endtask

  // Confere rk[0..10] e que os indices 11 a 15 devolvem 0:
  task automatic check_rks(input string tag, input int v);
    for (int i = 0; i < 11; i++) begin
      sel = i[3:0];
      @(negedge clk);
      check128($sformatf("%s rk[%0d]", tag, i), rk, vec_rk[v][i]);
    end
    for (int i = 11; i < 16; i++) begin
      sel = i[3:0];
      @(negedge clk);
      check128($sformatf("%s rk[%0d] (indice invalido)", tag, i), rk, '0);
    end
  endtask

  // Watchdog para evitar que a simulacao trave:
  initial begin
    repeat (TIMEOUT_CYCLES) @(posedge clk);
    $display("FAIL: watchdog - simulacao excedeu %0d ciclos", TIMEOUT_CYCLES);
    $fatal(1, "minisoc_aes_key_exp_tb: watchdog");
  end

  // Estimulos:
  int e0;
  int n;

  initial begin
    errors = 0;
    checks = 0;
    rst_n = 1'b0;
    key = '0;
    key_load = 1'b0;
    sel = '0;

    // Reset inicial:
    cycles(3);
    rst_n = 1'b1;
    cycles(2);
    e0 = errors;
    check1("key_ready apos reset", key_ready, 1'b0);
    for (int i = 0; i < 16; i++) begin
      sel = i[3:0];
      @(negedge clk);
      check128($sformatf("rk_o sem chave, indice %0d", i), rk, '0);
    end
    $display("[INFO] (1) Estado apos o reset: %0d erro(s)", errors - e0);

    // 12 chaves: latencia e 11 chaves de rodada:
    e0 = errors;
    for (int v = 0; v < N_VEC; v++) begin
      do_load(vec_key[v]);
      check1($sformatf("chave %0d: key_ready logo apos o load", v), key_ready, 1'b0);
      wait_ready(n);
      check_int($sformatf("chave %0d: latencia ate key_ready", v), n, LAT_EXPECTED);
      check_rks($sformatf("chave %0d", v), v);
    end
    $display("[INFO] (2) %0d chaves (latencia e 11 chaves de rodada cada): %0d erro(s)",
             N_VEC, errors - e0);

    // Chave capturada no load e estabilidade:
    e0 = errors;
    do_load(vec_key[5]);
    key = ~vec_key[5];
    wait_ready(n);
    check_int("captura: latencia", n, LAT_EXPECTED);
    check_rks("captura (key_i alterado)", 5);
    key = 128'hdeadbeefdeadbeefdeadbeefdeadbeef;
    cycles(20);
    check1("estabilidade: key_ready segue em 1", key_ready, 1'b1);
    check_rks("estabilidade apos 20 ciclos", 5);
    $display("[INFO] (3) Captura no load e estabilidade: %0d erro(s)", errors - e0);

    // Recarga no meio da expansao:
    e0 = errors;
    do_load(vec_key[2]);
    cycles(4);
    check1("recarga: key_ready no meio da expansao", key_ready, 1'b0);
    do_load(vec_key[7]);
    check1("recarga: key_ready logo apos o novo load", key_ready, 1'b0);
    wait_ready(n);
    check_int("recarga: latencia da nova chave", n, LAT_EXPECTED);
    check_rks("recarga (nova chave)", 7);
    $display("[INFO] (4) Recarga no meio da expansao: %0d erro(s)", errors - e0);

    // Novo load com as chaves prontas:
    e0 = errors;
    check1("novo load: key_ready antes", key_ready, 1'b1);
    do_load(vec_key[9]);
    check1("novo load: key_ready cai", key_ready, 1'b0);
    sel = 4'd0;
    @(negedge clk);
    check128("novo load: rk_o volta a 0 durante a expansao", rk, '0);
    wait_ready(n);
    check_rks("novo load", 9);
    $display("[INFO] (5) Novo load com chaves prontas: %0d erro(s)", errors - e0);

    // Reset no meio da expansao:
    e0 = errors;
    do_load(vec_key[3]);
    cycles(4);
    rst_n = 1'b0;
    cycles(2);
    check1("reset: key_ready em 0", key_ready, 1'b0);
    sel = 4'd0;
    @(negedge clk);
    check128("reset: rk_o em 0", rk, '0);
    rst_n = 1'b1;
    cycles(15);
    check1("reset: expansao nao continua sozinha", key_ready, 1'b0);
    do_load(vec_key[11]);
    wait_ready(n);
    check_int("reset: latencia apos nova carga", n, LAT_EXPECTED);
    check_rks("apos reset", 11);
    $display("[INFO] (6) Reset no meio da expansao: %0d erro(s)", errors - e0);

    // Resultado final:
    $display("--------------------------------------------------");
    if (errors == 0) begin
      $display("PASS: %0d verificacoes, 0 erros", checks);
      $finish;
    end else begin
      $display("FAIL: %0d verificacoes, %0d erro(s)", checks, errors);
      $fatal(1, "minisoc_aes_key_exp_tb falhou");
    end
  end

endmodule
