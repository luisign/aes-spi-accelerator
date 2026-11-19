module minisoc_spi_pll_tb;

  // Escala de tempo: 1 unidade = 50 ps, clk de 2 GHz tem periodo 10 e spi_sclk de 25 MHz tem periodo 800
  localparam int CLK_HALF = 5;
  localparam int SCLK_HALF = 400;
  localparam int TIMEOUT_CYCLES = 3000000;
  localparam int LOCK_MIN = 16;
  localparam int LOCK_MAX = 16 + 31 + 5;

  // DUTs e sinais:
  logic clk;
  logic rst_n;
  logic spi_sclk;
  logic spi_cs_n;
  logic spi_mosi;
  logic spi_miso;

  logic [127:0] cfg_key, cfg_iv;
  logic [63:0] cfg_counter;
  logic [31:0] cfg_num_blocks;
  logic [2:0] cfg_mode;
  logic cfg_decrypt;
  logic aes_start;
  logic mem_sel_aes;
  logic pll_enable;
  logic [1:0] pll_div_sel;
  logic pll_locked;
  logic sys_clk;

  logic aes_busy, aes_done, aes_error;
  logic [8:0] aes_blocks_done;

  minisoc_spi dut_spi (
    .clk (clk),
    .rst_n (rst_n),
    .spi_sclk (spi_sclk),
    .spi_cs_n (spi_cs_n),
    .spi_mosi (spi_mosi),
    .spi_miso (spi_miso),
    .cfg_key_o (cfg_key),
    .cfg_iv_o (cfg_iv),
    .cfg_counter_o (cfg_counter),
    .cfg_num_blocks_o (cfg_num_blocks),
    .cfg_mode_o (cfg_mode),
    .cfg_decrypt_o (cfg_decrypt),
    .aes_start_o (aes_start),
    .mem_sel_aes_o (mem_sel_aes),
    .pll_enable_o (pll_enable),
    .pll_div_sel_o (pll_div_sel),
    .aes_busy_i (aes_busy),
    .aes_done_i (aes_done),
    .aes_error_i (aes_error),
    .aes_blocks_done_i (aes_blocks_done),
    .pll_locked_i (pll_locked)
  );

  minisoc_pll_mock dut_pll (
    .clk_ref_i (clk),
    .rst_n (rst_n),
    .enable_i (pll_enable),
    .div_sel_i (pll_div_sel),
    .locked_o (pll_locked),
    .sys_clk_o (sys_clk)
  );

  initial clk = 1'b0;
  always #(CLK_HALF) clk = ~clk;

  // Contadores e utilitarios de verificacao:
  int errors;
  int checks;
  int dly_cnt;
  int cyc_cnt;
  int wd_cnt;

  task automatic check_int(input string name, input int got, input int exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[FAIL] %s: obtido=%0d esperado=%0d", name, got, exp);
    end
  endtask

  task automatic check32(input string name, input logic [31:0] got, input logic [31:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[FAIL] %s: obtido=%08h esperado=%08h", name, got, exp);
    end
  endtask

  task automatic check128(input string name, input logic [127:0] got, input logic [127:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("[FAIL] %s:\n obtido=%032h\n esperado=%032h", name, got, exp);
    end
  endtask

  task automatic check_range(input string name, input int got, input int lo, input int hi);
    checks++;
    if (got < lo || got > hi) begin
      errors++;
      $error("[FAIL] %s: obtido=%0d fora da faixa [%0d, %0d]", name, got, lo, hi);
    end
  endtask

  task automatic dly(input int t);
    #(t) dly_cnt = dly_cnt + 1;
  endtask

  task automatic cycles(input int n);
    repeat (n) @(negedge clk) cyc_cnt = cyc_cnt + 1;
  endtask

  // Watchdog:
  initial begin
    repeat (TIMEOUT_CYCLES) @(posedge clk) wd_cnt = wd_cnt + 1;
    $display("FAIL: watchdog - simulacao excedeu %0d ciclos", TIMEOUT_CYCLES);
    $fatal(1, "minisoc_spi_pll_tb: watchdog");
  end

  // Mestre SPI (mode 0, MSB-first):
  logic [39:0] mbits;

  task automatic spi_frame(
	input logic rwb,
  	input logic [5:0] addr,
  	input logic rsv,
        input logic [31:0] data,
        input int nbits
  );
  
    logic [39:0] f;
    f = {rwb, addr, rsv, data};
    mbits = '0;
    spi_cs_n = 1'b0;
    dly(SCLK_HALF / 2);
    for (int i = 0; i < nbits; i++) begin
      spi_mosi = f[39 - i];
      dly(SCLK_HALF);
      mbits[39 - i] = spi_miso;
      spi_sclk = 1'b1;
      dly(SCLK_HALF);
      spi_sclk = 1'b0;
    end
    dly(SCLK_HALF / 2);
    spi_cs_n = 1'b1;
    dly(SCLK_HALF);
  endtask

  // Escrita: o spi_miso deve ficar em 0 (exceto em frame NOP, que desloca o instantaneo):
  task automatic spi_write(input logic [5:0] addr, input logic [31:0] data);
    spi_frame(1'b0, addr, 1'b0, data, 40);
    if (addr != 6'h3F) check_int($sformatf("MISO em 0 na escrita (addr %02h)", addr), mbits != 0, 0);
  endtask

  // Leitura em duas transacoes: pedido (RWb = 1) e retorno (ADDR = NOP):
  logic [31:0] rdata;
  task automatic spi_read(input logic [5:0] addr);
    spi_frame(1'b1, addr, 1'b0, 32'hFFFF_FFFF, 40);
    check_int($sformatf("MISO em 0 no pedido de leitura (addr %02h)", addr), mbits != 0, 0);
    spi_frame(1'b0, 6'h3F, 1'b0, 32'h0, 40);
    check_int($sformatf("MISO nos 8 primeiros bits em 0 (addr %02h)", addr), mbits[39:32] != 0, 0);
    rdata = mbits[31:0];
  endtask

  task automatic expect_read(input string name, input logic [5:0] addr, input logic [31:0] exp);
    spi_read(addr);
    check32(name, rdata, exp);
  endtask

  // Monitores:
  // Pulso de START:
  int start_cnt, start_wide;
  logic start_prev;
  always @(posedge clk) begin
    if (aes_start) begin
      start_cnt = start_cnt + 1;
      if (start_prev) start_wide = start_wide + 1;
    end
    start_prev = aes_start;
  end

  // sys_clk: periodo, ciclo de trabalho e "nunca sobe com locked = 0":
  time t_rise_prev;
  time per, hi;
  time min_per, max_per, min_hi, max_hi;
  int n_rise;
  int clk_viol;

  task automatic reset_mon();
    n_rise = 0;
    min_per = 64'hFFFF_FFFF; max_per = 64'd0;
    min_hi = 64'hFFFF_FFFF; max_hi = 64'd0;
  endtask

  always @(posedge sys_clk) begin
    if (!pll_locked) begin
      clk_viol = clk_viol + 1;
      if (clk_viol <= 3) $error("[FAIL] sys_clk subiu com PLL_LOCKED = 0");
    end
    if (n_rise > 0) begin
      per = $time - t_rise_prev;
      if (per < min_per) min_per = per;
      if (per > max_per) max_per = per;
    end
    t_rise_prev = $time;
    n_rise = n_rise + 1;
  end

  always @(negedge sys_clk) begin
    if (n_rise > 0) begin
      hi = $time - t_rise_prev;
      if (hi < min_hi) min_hi = hi;
      if (hi > max_hi) max_hi = hi;
    end
  end

  // Latencia do lock: ciclos de clk do inicio da aquisicao (enable ou troca de divisor) ate PLL_LOCKED:
  time t_acq;
  int lock_lat;
  always @(posedge pll_enable) t_acq = $time;
  always @(pll_div_sel) if (pll_enable) t_acq = $time;
  always @(posedge pll_locked) lock_lat = int'(($time - t_acq) / (2 * CLK_HALF));

  // Modelo dos registradores R/W:
  function automatic logic [31:0] rw_mask(input int a);
    if (a <= 10) return 32'hFFFF_FFFF; // KEY, IV, COUNTER, NUM_BLOCKS
    else if (a == 11) return 32'h0000_001E; // AES_CONTROL: MODE[4:2], DECRYPT[1] (START le 0)
    else if (a == 14) return 32'h0000_000F; // SYSTEM_CONTROL: DIV_SEL[3:2], PLL_ENABLE[1], MEM_SEL[0]
    else return 32'h0;
  endfunction

  function automatic logic [31:0] pattern(input int p, input int a);
    logic [31:0] v;
    v = 32'hA5C3_0F81 ^ (a * 32'h0101_0101);
    case (p)
      0: v = v;
      1: v = ~v;
      default: v = (a % 2) ? 32'hFFFF_FFFF : 32'h0000_0000;
    endcase
    if (a == 11) v[0] = 1'b0;
    return v;
  endfunction

  int rw_addr [13];
  initial begin
    for (int i = 0; i < 11; i++) rw_addr[i] = i;
    rw_addr[11] = 11;
    rw_addr[12] = 14;
  end

  logic [31:0] exp_reg [16];

  // Teste do PLL para um divisor:
  task automatic pll_test(input int d);
    int polls;
    int ratio;
    ratio = 1 << d;

    // SYSTEM_CONTROL = PLL_DIV_SEL, PLL_ENABLE = 1, MEM_SEL_AES = 0:
    reset_mon();
    spi_write(6'h0E, (d << 2) | 32'h2);
    polls = 0;
    do begin
      spi_read(6'h0F);
      polls = polls + 1;
    end while (rdata[0] !== 1'b1 && polls < 5);
    check32($sformatf("div /%0d: SYSTEM_STATUS.PLL_LOCKED", ratio), rdata, 32'h1);
    check_range($sformatf("div /%0d: latencia do lock (ciclos de clk)", ratio), lock_lat, LOCK_MIN, LOCK_MAX);
    check_int($sformatf("div /%0d: PLL_LOCKED no pino", ratio), pll_locked, 1);

    // Clock de sistema: periodo e ciclo de trabalho:
    reset_mon();
    dly(6000);
    check_range($sformatf("div /%0d: bordas de sys_clk", ratio), n_rise, 2, 100000);
    check_int($sformatf("div /%0d: periodo minimo", ratio), min_per, 10 * ratio);
    check_int($sformatf("div /%0d: periodo maximo", ratio), max_per, 10 * ratio);
    check_int($sformatf("div /%0d: largura alta minima", ratio), min_hi, 5 * ratio);
    check_int($sformatf("div /%0d: largura alta maxima", ratio), max_hi, 5 * ratio);
  endtask

  task automatic pll_disable_test(input string tag);
    spi_write(6'h0E, 32'h0);
    dly(2000);
    reset_mon();
    dly(3000);
    check_int({tag, ": PLL_LOCKED cai ao desabilitar"}, pll_locked, 0);
    check_int({tag, ": sys_clk parado"}, n_rise, 0);
    check_int({tag, ": sys_clk em 0"}, sys_clk, 0);
    expect_read({tag, ": SYSTEM_STATUS apos desabilitar"}, 6'h0F, 32'h0);
  endtask

  // Estimulos:
  int e0;
  int lat0, lat1, lat2, lat3;
  logic [31:0] pat;

  initial begin
    errors = 0;
    checks = 0;
    dly_cnt = 0;
    cyc_cnt = 0;
    wd_cnt = 0;
    start_cnt = 0;
    start_wide = 0;
    start_prev = 1'b0;
    lock_lat = 0;
    clk_viol = 0;
    reset_mon();
    aes_busy = 1'b0;
    aes_done = 1'b0;
    aes_error = 1'b0;
    aes_blocks_done = '0;
    spi_sclk = 1'b0;
    spi_mosi = 1'b0;
    spi_cs_n = 1'b1;
    rst_n = 1'b0;
    cycles(8);
    rst_n = 1'b1;
    cycles(8);

    // Valores de reset:
    e0 = errors;
    for (int a = 0; a < 16; a++) begin
      expect_read($sformatf("reset: registrador 0x%02h", a), a[5:0], (a == 13) ? 32'h0001_0000 : 32'h0);
    end
    expect_read("nao mapeado 0x10", 6'h10, 32'h0);
    expect_read("nao mapeado 0x20", 6'h20, 32'h0);
    expect_read("nao mapeado 0x3E", 6'h3E, 32'h0);
    $display("[INFO] (1) Valores de reset (16 registradores e 3 enderecos nao mapeados): %0d erro(s)", errors - e0);

    // R/W: escrita e leitura de todos os registradores:
    e0 = errors;
    for (int p = 0; p < 3; p++) begin
      for (int i = 0; i < 13; i++) begin
        pat = pattern(p, rw_addr[i]);
        exp_reg[rw_addr[i]] = pat & rw_mask(rw_addr[i]);
        spi_write(rw_addr[i][5:0], pat);
        expect_read($sformatf("R/W padrao %0d: registrador 0x%02h", p, rw_addr[i]),
                    rw_addr[i][5:0], exp_reg[rw_addr[i]]);
      end
      check128($sformatf("padrao %0d: cfg_key", p), cfg_key,
               {exp_reg[0], exp_reg[1], exp_reg[2], exp_reg[3]});
      check128($sformatf("padrao %0d: cfg_iv", p), cfg_iv,
               {exp_reg[4], exp_reg[5], exp_reg[6], exp_reg[7]});
      check32($sformatf("padrao %0d: cfg_counter hi", p), cfg_counter[63:32], exp_reg[8]);
      check32($sformatf("padrao %0d: cfg_counter lo", p), cfg_counter[31:0], exp_reg[9]);
      check32($sformatf("padrao %0d: cfg_num_blocks", p), cfg_num_blocks, exp_reg[10]);
      check_int($sformatf("padrao %0d: cfg_mode", p), cfg_mode, exp_reg[11][4:2]);
      check_int($sformatf("padrao %0d: cfg_decrypt", p), cfg_decrypt, exp_reg[11][1]);
      check_int($sformatf("padrao %0d: mem_sel_aes", p), mem_sel_aes, exp_reg[14][0]);
      check_int($sformatf("padrao %0d: pll_enable", p), pll_enable, exp_reg[14][1]);
      check_int($sformatf("padrao %0d: pll_div_sel", p), pll_div_sel, exp_reg[14][3:2]);
      check_int($sformatf("padrao %0d: START nao disparou", p), start_cnt, 0);
    end
    spi_write(6'h0E, 32'h0);
    $display("[INFO] (2) 13 registradores R/W, 3 padroes (escrita, leitura e saidas): %0d erro(s)", errors - e0);

    // Registradores R nao mudam com escrita:
    e0 = errors;
    aes_busy = 1'b1;  aes_done = 1'b0;  aes_error = 1'b1;  aes_blocks_done = 9'h155;
    dly(500);
    spi_write(6'h0C, 32'hFFFF_FFFF);
    spi_write(6'h0D, 32'hFFFF_FFFF);
    spi_write(6'h0F, 32'hFFFF_FFFF);
    expect_read("AES_STATUS apos escrita", 6'h0C, {20'd0, 9'h155, 1'b1, 1'b0, 1'b1});
    expect_read("VERSION apos escrita", 6'h0D, 32'h0001_0000);
    expect_read("SYSTEM_STATUS apos escrita", 6'h0F, 32'h0);
    aes_busy = 1'b0;  aes_done = 1'b1;  aes_error = 1'b0; aes_blocks_done = 9'h0A5;
    dly(500);
    expect_read("AES_STATUS reflete as entradas", 6'h0C, {20'd0, 9'h0A5, 1'b0, 1'b1, 1'b0});
    aes_done = 1'b0;  aes_blocks_done = '0;
    $display("[INFO] (3) Registradores somente leitura inalterados por escrita: %0d erro(s)", errors - e0);

    // START sem lock:
    e0 = errors;
    start_cnt = 0;
    spi_write(6'h0B, 32'h0000_001F);
    dly(2000);
    check_int("START sem PLL_LOCKED: nenhum pulso", start_cnt, 0);
    expect_read("AES_CONTROL apos START sem lock", 6'h0B, 32'h0000_001E);
    $display("[INFO] (4) START sem PLL_LOCKED e ignorado: %0d erro(s)", errors - e0);

    // PLL pelos quatro divisores:
    e0 = errors;
    pll_test(0); lat0 = lock_lat;
    pll_disable_test("div /1");
    pll_test(1); lat1 = lock_lat;
    pll_disable_test("div /2");
    pll_test(2); lat2 = lock_lat;
    pll_disable_test("div /4");
    pll_test(3); lat3 = lock_lat;
    check_int("latencias do lock nao sao todas iguais", (lat0 == lat1) && (lat1 == lat2) && (lat2 == lat3), 0);

    // START com o lock real do PLL (divisor /8 ainda habilitado):
    start_cnt = 0;  start_wide = 0;
    spi_write(6'h0B, 32'h0000_0003);
    dly(2000);
    check_int("START com PLL_LOCKED: um pulso", start_cnt, 1);
    check_int("START com PLL_LOCKED: pulso de 1 ciclo", start_wide, 0);
    expect_read("AES_CONTROL le START como 0", 6'h0B, 32'h0000_0002);
    check_int("cfg_decrypt apos START", cfg_decrypt, 1);

    // Troca de divisor com o PLL habilitado: perde o lock e readquire com o novo:
    spi_write(6'h0E, 32'h0000_0006);
    spi_read(6'h0F);
    reset_mon();
    dly(6000);
    check_int("troca /8 -> /2: PLL_LOCKED apos readquirir", pll_locked, 1);
    check_int("troca /8 -> /2: periodo minimo", min_per, 20);
    check_int("troca /8 -> /2: periodo maximo", max_per, 20);
    check_range("troca /8 -> /2: latencia da readquisicao", lock_lat, LOCK_MIN, LOCK_MAX);
    pll_disable_test("apos a troca");
    $display("[INFO] (5) PLL: 4 divisores, lock, clock, desabilitar, troca de divisor e START: %0d erro(s)", errors - e0);

    // Casos de borda do SPI:
    e0 = errors;
    spi_write(6'h00, 32'h1111_1111);
    spi_frame(1'b0, 6'h00, 1'b0, 32'h2222_2222, 39); // frame de 39 bits
    expect_read("frame de 39 bits descartado", 6'h00, 32'h1111_1111);
    spi_write(6'h00, 32'h3333_3333);
    expect_read("frame completo apos o curto", 6'h00, 32'h3333_3333);
    spi_frame(1'b0, 6'h00, 1'b1, 32'h4444_4444, 40); // RSV = 1 (escrita)
    expect_read("RSV = 1 ignorado na escrita", 6'h00, 32'h3333_3333);
    spi_write(6'h01, 32'h5555_5555);
    spi_read(6'h01); // snapshot de KEY1
    spi_frame(1'b1, 6'h00, 1'b1, 32'h0, 40); // pedido com RSV = 1: ignorado
    spi_frame(1'b0, 6'h3F, 1'b0, 32'h0, 40);
    check32("RSV = 1 ignorado no pedido de leitura", mbits[31:0], 32'h5555_5555);
    spi_write(6'h3F, 32'hFFFF_FFFF); // NOP
    spi_write(6'h10, 32'hFFFF_FFFF); // nao mapeado
    spi_write(6'h2A, 32'hFFFF_FFFF); // nao mapeado
    expect_read("NOP e nao mapeado: KEY0 intacta", 6'h00, 32'h3333_3333);
    expect_read("NOP e nao mapeado: KEY1 intacta", 6'h01, 32'h5555_5555);
    aes_busy = 1'b0;  aes_blocks_done = 9'h001;  dly(500);
    spi_frame(1'b1, 6'h0C, 1'b0, 32'h0, 40);
    aes_busy = 1'b1;  aes_blocks_done = 9'h1FF;  dly(500);
    spi_frame(1'b0, 6'h3F, 1'b0, 32'h0, 40);
    check32("instantaneo do status", mbits[31:0], {20'd0, 9'h001, 1'b0, 1'b0, 1'b0});
    aes_busy = 1'b0;  aes_blocks_done = '0;
    spi_frame(1'b0, 6'h05, 1'b0, 32'hFFFF_FFFF, 40); // MISO em 0 fora do NOP
    check_int("MISO em 0 em frame que nao e NOP", mbits != 0, 0);
    $display("[INFO] (6) Casos de borda do SPI: %0d erro(s)", errors - e0);

    // Reset no meio da operacao:
    e0 = errors;
    spi_write(6'h0E, 32'h0000_000A);
    dly(3000);
    check_int("antes do reset: PLL travado", pll_locked, 1);
    rst_n = 1'b0;
    cycles(4);
    check_int("reset: PLL_LOCKED em 0", pll_locked, 0);
    check_int("reset: pll_enable em 0", pll_enable, 0);
    rst_n = 1'b1;
    cycles(4);
    expect_read("reset: KEY0 zerada", 6'h00, 32'h0);
    expect_read("reset: SYSTEM_CONTROL zerado", 6'h0E, 32'h0);
    expect_read("reset: VERSION mantida", 6'h0D, 32'h0001_0000);
    $display("[INFO] (7) Reset no meio da operacao: %0d erro(s)", errors - e0);

    // sys_clk nunca sobe com PLL_LOCKED = 0 (monitor ativo durante todo o teste):
    check_int("sys_clk nunca subiu com PLL_LOCKED = 0 (bordas indevidas)", clk_viol, 0);

    // Resultado final:
    $display("--------------------------------------------------");
    if (errors == 0) begin
      $display("PASS: %0d verificacoes, 0 erros", checks);
      $finish;
    end else begin
      $display("FAIL: %0d verificacoes, %0d erro(s)", checks, errors);
      $fatal(1, "minisoc_spi_pll_tb falhou");
    end
  end

endmodule
