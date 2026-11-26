module minisoc_aes_top_tb;

  localparam int PM = 10; // periodo de mem_clk
  localparam int PA = 14; // periodo de sys_clk
  localparam int N_SIZES = 3;
  localparam int TIMEOUT_CYCLES = 3000000; // watchdog (ciclos de sys_clk)
  localparam int MAX_WAIT = 20000; // espera maxima por operacao (ciclos de sys_clk)

  localparam int OVERHEAD_CYC = 16;
  localparam int PER_BLOCK_CYC = 22;
  localparam int ERROR_CYC = 4;

  // Sinais e DUTs:
  logic rst_n;
  logic mem_clk;
  logic sys_clk;
  logic mem_sel;
  logic [31:0] ext_wdata;
  logic [9:0] ext_addr;
  logic ext_we;
  logic [31:0] ext_rdata;
  logic ext_own, aes_own;

  logic [127:0] cfg_key, cfg_iv;
  logic [63:0] cfg_counter;
  logic [31:0] cfg_num_blocks;
  logic [2:0] cfg_mode;
  logic cfg_decrypt;
  logic start;
  logic busy, done, error;
  logic [8:0] blocks_done;

  logic [9:0] m_addr;
  logic [31:0] m_wdata, m_rdata;
  logic m_we;

  minisoc_aes_top dut_aes (
    .clk (sys_clk),
    .rst_n (rst_n),
    .cfg_key_i (cfg_key),
    .cfg_iv_i (cfg_iv),
    .cfg_counter_i (cfg_counter),
    .cfg_num_blocks_i (cfg_num_blocks),
    .cfg_mode_i (cfg_mode),
    .cfg_decrypt_i (cfg_decrypt),
    .start_i (start),
    .busy_o (busy),
    .done_o (done),
    .error_o (error),
    .blocks_done_o (blocks_done),
    .mem_addr_o (m_addr),
    .mem_wdata_o (m_wdata),
    .mem_we_o (m_we),
    .mem_rdata_i (m_rdata)
  );

  minisoc_memory dut_mem (
    .rst_n (rst_n),
    .mem_sel_aes_i (mem_sel),
    .mem_clk (mem_clk),
    .mem_i_data (ext_wdata),
    .mem_i_wr_en (ext_we),
    .mem_i_addr (ext_addr),
    .mem_o_data (ext_rdata),
    .aes_clk (sys_clk),
    .aes_addr_i (m_addr),
    .aes_wdata_i (m_wdata),
    .aes_we_i (m_we),
    .aes_rdata_o (m_rdata),
    .ext_own_o (ext_own),
    .aes_own_o (aes_own)
  );

  initial mem_clk = 1'b0;
  initial sys_clk = 1'b0;
  always #(PM / 2) mem_clk = ~mem_clk;
  always #(PA / 2) sys_clk = ~sys_clk;

  // Contadores e utilitarios de verificacao:
  int errors;
  int checks;
  int dly_cnt; // para que as esperas nao sejam null statement quando rodar o lint
  int cyc_m;
  int cyc_a;
  int wd_cnt;

  task automatic check_int(input string name, input int got, input int exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[FAIL] %s: obtido=%0d esperado=%0d", name, got, exp);
    end
  endtask

  task automatic check_bit(input string name, input logic got, input logic exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[FAIL] %s: obtido=%b esperado=%b", name, got, exp);
    end
  endtask

  task automatic dly(input int t);
    #(t) dly_cnt = dly_cnt + 1;
  endtask

  task automatic cyc_mem(input int n);
    repeat (n) @(negedge mem_clk) cyc_m = cyc_m + 1;
  endtask

  task automatic cyc_aes(input int n);
    repeat (n) @(negedge sys_clk) cyc_a = cyc_a + 1;
  endtask

  // Watchdog e monitores:
  initial begin
    wd_cnt = 0;
    repeat (TIMEOUT_CYCLES) @(posedge sys_clk) wd_cnt = wd_cnt + 1;
    $display("FAIL: watchdog - simulacao excedeu %0d ciclos de sys_clk", TIMEOUT_CYCLES);
    $fatal(1, "minisoc_aes_top_tb: watchdog");
  end

  int mon_we_idle;
  int mon_busy_done;
  always @(negedge sys_clk) begin
    if (rst_n === 1'b1) begin
      if (m_we === 1'b1 && busy === 1'b0) mon_we_idle = mon_we_idle + 1;
      if (busy === 1'b1 && done === 1'b1) mon_busy_done = mon_busy_done + 1;
    end
  end

  // Memoria pela interface MEMORY_DATA:
  function automatic logic [31:0] sentinel(input int a);
    logic [9:0] a10;
    a10 = a[9:0];
    return {a10, 22'h2A5A5A} ^ 32'h5A5A5A5A;
  endfunction

  task automatic ext_write(input int a, input logic [31:0] d);
    @(negedge mem_clk) cyc_m = cyc_m + 1;
    ext_addr = a[9:0];
    ext_wdata = d;
    ext_we = 1'b1;
    @(negedge mem_clk) cyc_m = cyc_m + 1;
    ext_we = 1'b0;
  endtask

  logic [31:0] snap [1024];

  // Le a memoria inteira (1 palavra por ciclo, o dado chega 1 ciclo depois do endereco):
  task automatic ext_read_all();
    @(negedge mem_clk) cyc_m = cyc_m + 1;
    ext_we = 1'b0;
    for (int i = 0; i <= 1024; i++) begin
      if (i > 0) snap[i - 1] = ext_rdata;
      if (i < 1024) ext_addr = i[9:0];
      @(negedge mem_clk) cyc_m = cyc_m + 1;
    end
  endtask

  // Troca de posse da memoria:
  int sel_phase;
  task automatic set_sel(input logic v);
    int n;
    sel_phase = (sel_phase + 4) % 17; // instante da troca varia, sempre assincrono
    dly(3 + sel_phase);
    mem_sel = v;
    n = 0;
    while (!(v ? (aes_own === 1'b1 && ext_own === 1'b0)
               : (ext_own === 1'b1 && aes_own === 1'b0)) && n < 200) begin
      dly(PM);
      n++;
    end
    check_int($sformatf("posse da memoria concluida (MEM_SEL_AES=%0d)", v), n < 200, 1);
    cyc_mem(12);
  endtask

  task automatic fill_sentinel();
    for (int a = 0; a < 1024; a++) ext_write(a, sentinel(a));
  endtask

  // Comando do AES (dominio sys_clk):
  logic [31:0] cfg [15]; // KEY0..3, IV0..3, CTR_HI, CTR_LO, NUM_BLOCKS, MODE, DECRYPT, EXPECT_ERROR, REGION_WORDS:
  logic [31:0] in_m [1024];
  logic [31:0] exp_m [1024];

  task automatic apply_cfg();
    cfg_key = {cfg[0], cfg[1], cfg[2], cfg[3]};
    cfg_iv = {cfg[4], cfg[5], cfg[6], cfg[7]};
    cfg_counter = {cfg[8], cfg[9]};
    cfg_num_blocks = cfg[10];
    cfg_mode = cfg[11][2:0];
    cfg_decrypt = cfg[12][0];
  endtask

  task automatic pulse_start();
    @(negedge sys_clk) cyc_a = cyc_a + 1;
    start = 1'b1;
    @(negedge sys_clk) cyc_a = cyc_a + 1;
    start = 1'b0;
  endtask

  // Espera DONE = 1 e BUSY = 0 e devolve os ciclos contados a partir do ciclo seguinte ao pulso de START:
  task automatic wait_finish(output int c);
    c = 0;
    while (!(done === 1'b1 && busy === 1'b0) && c < MAX_WAIT) begin
      @(negedge sys_clk) cyc_a = cyc_a + 1;
      c++;
    end
  endtask

  // Carrega um caso do modelo de referencia (tb/vectors/):
  task automatic load_case(input string name);
    $readmemh({"tb/vectors/", name, "_cfg.hex"}, cfg);
    $readmemh({"tb/vectors/", name, "_in.hex"}, in_m);
    $readmemh({"tb/vectors/", name, "_exp.hex"}, exp_m);
  endtask

  // Compara a memoria lida (snap) com o esperado: regiao [0, region) = expected[], resto = padrao sentinela, e imprime as 3 primeiras divergencias:
  task automatic compare_memory(input string name, input int region, input int use_in);
    int bad;
    logic [31:0] e;
    bad = 0;
    for (int w = 0; w < 1024; w++) begin
      if (w < region) e = use_in ? in_m[w] : exp_m[w];
      else e = sentinel(w);
      checks++;
      if (snap[w] !== e) begin
        errors++;
        bad++;
        if (bad <= 3) $error("[FAIL] %s: mem[%0d]=%08h esperado=%08h", name, w, snap[w], e);
      end
    end
  endtask

  // Executa um caso completo: force_mode >= 0 troca o MODE (caso de modo nao implementado):
  int last_cycles;
  task automatic run_case(input string name, input int force_mode);
    int region, nb, experr, c;
    logic [8:0] exp_bd;
    load_case(name);
    region = cfg[14];
    nb = cfg[10];
    experr = cfg[13];
    if (force_mode >= 0) begin
      cfg[11] = force_mode;
      experr = 1;
    end

    set_sel(1'b0);
    fill_sentinel();
    for (int w = 0; w < region; w++) ext_write(w, in_m[w]);
    set_sel(1'b1);
    apply_cfg();
    pulse_start();
    wait_finish(c);
    last_cycles = c;

    exp_bd = experr ? 9'd0 : nb[8:0];
    check_bit({name, ": ERROR"}, error, experr[0]);
    check_bit({name, ": DONE"},  done, 1'b1);
    check_bit({name, ": BUSY"},  busy, 1'b0);
    check_int({name, ": BLOCKS_DONE"}, blocks_done, exp_bd);
    check_int({name, ": latencia (ciclos)"}, c, experr ? ERROR_CYC : OVERHEAD_CYC + PER_BLOCK_CYC * nb);

    set_sel(1'b0);
    ext_read_all();
    compare_memory(name, region, (force_mode >= 0) ? 1 : (experr ? 1 : 0));
  endtask

  // Estimulos:
  int e0;
  int cc;
  string nm;
  string mode_n [3];
  string dir_n [2];
  int sizes [N_SIZES];

  initial begin
    errors = 0;
    checks = 0;
    dly_cnt = 0;
    cyc_m = 0;
    cyc_a = 0;
    mon_we_idle = 0;
    mon_busy_done = 0;
    sel_phase = 0;
    mode_n[0] = "ecb"; mode_n[1] = "cbc"; mode_n[2] = "ctr";
    dir_n[0] = "enc"; dir_n[1] = "dec";
    sizes[0] = 1; sizes[1] = 2; sizes[2] = 256;

    ext_wdata = '0;
    ext_addr = '0;
    ext_we = 1'b0;
    mem_sel = 1'b0;
    start = 1'b0;
    cfg_key = '0;
    cfg_iv = '0;
    cfg_counter = '0;
    cfg_num_blocks = '0;
    cfg_mode = '0;
    cfg_decrypt = 1'b0;
    rst_n = 1'b0;
    dly(10 * PM);
    rst_n = 1'b1;
    dly(10 * PM);

    // Estado apos o reset:
    e0 = errors;
    check_bit("reset: BUSY", busy, 1'b0);
    check_bit("reset: DONE", done, 1'b0);
    check_bit("reset: ERROR", error, 1'b0);
    check_int("reset: BLOCKS_DONE", blocks_done, 0);
    check_bit("reset: posse externa", ext_own, 1'b1);
    $display("[INFO] (1) Estado apos o reset: %0d erro(s)", errors - e0);

    // ECB, CBC e CTR, cifra e decifra, 1, 2 e 256 blocos:
    e0 = errors;
    for (int m = 0; m < 3; m++) begin
      for (int d = 0; d < 2; d++) begin
        for (int s = 0; s < N_SIZES; s++) begin
          nm = $sformatf("%s_%s_%0dblk", mode_n[m], dir_n[d], sizes[s]);
          run_case(nm, -1);
        end
      end
    end
    $display("[INFO] (2) ECB, CBC e CTR, cifra e decifra, 1/2/256 blocos (18 casos): %0d erro(s)", errors - e0);

    // Configuracao invalida:
    e0 = errors;
    run_case("err_nblocks0", -1);
    run_case("err_nblocks257", -1);
    run_case("err_mode6", -1);
    run_case("err_mode7", -1);
    $display("[INFO] (3) Configuracao invalida (NUM_BLOCKS 0 e 257, MODE 6 e 7): %0d erro(s)", errors - e0);

    // Limitacao de modos PCBC, CFB e OFB:
    e0 = errors;
    run_case("ecb_enc_2blk", 2);
    run_case("ecb_enc_2blk", 3);
    run_case("ecb_enc_2blk", 4);
    $display("[INFO] (4) Modos nao implementados (PCBC, CFB, OFB) geram ERROR: %0d erro(s)", errors - e0);

    // DONE, ERROR, START:
    e0 = errors;
    run_case("err_mode6", -1); // termina com ERROR = 1 e DONE = 1
    cyc_aes(200);
    check_bit("sticky: DONE apos 200 ciclos", done, 1'b1);
    check_bit("sticky: ERROR apos 200 ciclos", error, 1'b1);
    check_bit("sticky: BUSY apos 200 ciclos", busy, 1'b0);
    load_case("cbc_dec_2blk");
    set_sel(1'b0);
    fill_sentinel();
    for (int w = 0; w < 8; w++) ext_write(w, in_m[w]);
    set_sel(1'b1);
    apply_cfg();
    pulse_start();
    cyc_aes(2);
    check_bit("novo START: DONE limpo", done, 1'b0);
    check_bit("novo START: ERROR limpo", error, 1'b0);
    check_bit("novo START: BUSY sobe", busy, 1'b1);

    // START e configuracao durante BUSY:
    cyc_aes(10);
    cfg_key = 128'hDEAD; cfg_iv = 128'hBEEF; cfg_mode = 3'd0; cfg_decrypt = 1'b0;
    cfg_num_blocks = 32'd1; cfg_counter = 64'd7;
    cyc_aes(5);
    pulse_start();
    cyc_aes(20);
    pulse_start();
    wait_finish(cc);
    check_bit("durante BUSY: ERROR",   error, 1'b0);
    check_int("durante BUSY: BLOCKS_DONE", blocks_done, 2);
    set_sel(1'b0);
    ext_read_all();
    compare_memory("durante BUSY (cbc_dec_2blk)", 8, 0);
    $display("[INFO] (5)+(6) DONE/ERROR sticky, novo START e START/configuracao durante BUSY: %0d erro(s)", errors - e0);

    // Operacoes em sequencia, chaves e modos diferentes, sem reset:
    e0 = errors;
    run_case("ctr_enc_2blk", -1);
    run_case("ecb_dec_1blk", -1);
    run_case("cbc_enc_2blk", -1);
    run_case("ctr_dec_1blk", -1);
    $display("[INFO] (7) Operacoes em sequencia sem reset: %0d erro(s)", errors - e0);

    // Reset no meio de uma operacao:
    e0 = errors;
    load_case("ecb_enc_256blk");
    set_sel(1'b0);
    fill_sentinel();
    for (int w = 0; w < 1024; w++) ext_write(w, in_m[w]);
    set_sel(1'b1);
    apply_cfg();
    pulse_start();
    cyc_aes(200);
    check_bit("reset no meio: BUSY antes do reset", busy, 1'b1);
    rst_n = 1'b0;
    cyc_aes(4);
    check_bit("reset no meio: BUSY", busy, 1'b0);
    check_bit("reset no meio: DONE", done, 1'b0);
    check_bit("reset no meio: ERROR", error, 1'b0);
    check_int("reset no meio: BLOCKS_DONE", blocks_done, 0);
    rst_n = 1'b1;
    cyc_aes(10);
    run_case("cbc_enc_2blk", -1);
    $display("[INFO] (8) Reset no meio de uma operacao: %0d erro(s)", errors - e0);

    // Monitores:
    check_int("mem_we_o nunca sobe com BUSY = 0", mon_we_idle, 0);
    check_int("BUSY e DONE nunca sao 1 ao mesmo tempo", mon_busy_done, 0);

    // Resultado final:
    $display("--------------------------------------------------");
    if (errors == 0) begin
      $display("PASS: %0d verificacoes, 0 erros", checks);
      $finish;
    end else begin
      $display("FAIL: %0d verificacoes, %0d erro(s)", checks, errors);
      $fatal(1, "minisoc_aes_top_tb falhou");
    end
  end

endmodule
