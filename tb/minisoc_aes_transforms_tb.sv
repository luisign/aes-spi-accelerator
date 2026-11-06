// Verificacoes do testbench:
//  (1) S-box e S-box inversa nas 256 entradas, contra referencia aqui
//      do testbench (inverso em GF(2^8) + transformacao afim; a inversa e a
//      permutacao inversa dessa tabela).
//  (2) Cifragem (chave 2b7e1516...): rodadas 1 a 10 de
//      SubBytes e ShiftRows, rodadas 1 a 9 de MixColumns e as 11 chaves de rodada
//      do AddRoundKey (incluindo a rodada inicial e a cifra final).
//  (3) Cifragem inversa, (chave 000102...0f): rodadas 10 a 1
//      de InvShiftRows, InvSubBytes e AddRoundKey, rodadas 10 a 2 de InvMixColumns.
//  (4) Propriedades de inversa em vetores pseudoaleatorios deterministicos:
//      InvSubBytes(SubBytes(x)) = x, InvShiftRows(ShiftRows(x)) = x,
//      InvMixColumns(MixColumns(x)) = x e AddRoundKey aplicada duas vezes = x.
//  (5) MixColumns e InvMixColumns contra um modelo de referencia do testbench
//      (multiplicacao em GF(2^8) com os coeficientes da FIPS-197), em vetores
//      pseudoaleatorios.
// Em caso de falha,
// termina com $fatal (codigo de saida diferente de zero).

module minisoc_aes_transforms_tb;

  localparam int N_RAND = 200; // vetores pseudoaleatorios por propriedade

  // DUTs:

  logic [7:0] sbox_in, sbox_out;
  logic [7:0] isbox_in, isbox_out;
  logic [127:0] sb_in, sb_out;
  logic [127:0] sr_in, sr_out;
  logic [127:0] mc_in, mc_out;
  logic [127:0] ark_in, ark_key, ark_out;
  logic [127:0] isb_in, isb_out;
  logic [127:0] isr_in, isr_out;
  logic [127:0] imc_in, imc_out;

  minisoc_aes_sbox u_sbox  (.data_i(sbox_in), .data_o(sbox_out));
  minisoc_aes_inv_sbox u_isbox (.data_i(isbox_in), .data_o(isbox_out));
  minisoc_aes_sub_bytes u_sb (.state_i(sb_in), .state_o(sb_out));
  minisoc_aes_shift_rows u_sr (.state_i(sr_in), .state_o(sr_out));
  minisoc_aes_mix_columns u_mc (.state_i(mc_in), .state_o(mc_out));
  minisoc_aes_add_round_key u_ark (.state_i(ark_in), .round_key_i(ark_key), .state_o(ark_out));
  minisoc_aes_inv_sub_bytes u_isb (.state_i(isb_in), .state_o(isb_out));
  minisoc_aes_inv_shift_rows u_isr (.state_i(isr_in), .state_o(isr_out));
  minisoc_aes_inv_mix_columns u_imc (.state_i(imc_in), .state_o(imc_out));

  // Modelo de referencia:
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

  // Inverso multiplicativo por forca bruta: 0 -> 0:
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

  // S-box = inverso + transformacao afim:
  function automatic logic [7:0] sbox_ref(input logic [7:0] x);
    logic [7:0] b;
    b = gf_inv(x);
    return b ^ rotl8(b, 1) ^ rotl8(b, 2) ^ rotl8(b, 3) ^ rotl8(b, 4) ^ 8'h63;
  endfunction

  // Tabelas de referencia (preenchidas uma vez no inicio): S-box e S-box inversa:
  logic [7:0] ref_sbox [256];
  logic [7:0] ref_inv  [256];

  // Coeficientes da primeira linha da matriz: MixColumns {02,03,01,01}:
  // e InvMixColumns {0e,0b,0d,09}. A linha r e a primeira linha rotacionada a direita:
  function automatic logic [7:0] coef(input logic inv, input int idx);
    if (!inv) begin
      case (idx)
        0: return 8'h02;
        1: return 8'h03;
        default: return 8'h01;
      endcase
    end else begin
      case (idx)
        0: return 8'h0e;
        1: return 8'h0b;
        2: return 8'h0d;
        default: return 8'h09;
      endcase
    end
  endfunction

  function automatic logic [127:0] mix_ref(input logic [127:0] s, input logic inv);
    logic [127:0] res;
    logic [7:0]   acc;
    res = '0;
    for (int c = 0; c < 4; c++) begin
      for (int r = 0; r < 4; r++) begin
        acc = 8'h00;
        for (int k = 0; k < 4; k++) begin
          acc = acc ^ gf_mul(s[127 - 8*(4*c + k) -: 8], coef(inv, (k - r + 4) % 4));
        end
        res[127 - 8*(4*c + r) -: 8] = acc;
      end
    end
    return res;
  endfunction

  // Gerador pseudoaleatorio deterministico (xorshift32): mesma sequencia sempre:

  logic [31:0] rng;

  task automatic next_rand(output logic [127:0] v);
    for (int w = 0; w < 4; w++) begin
      rng = rng ^ (rng << 13);
      rng = rng ^ (rng >> 17);
      rng = rng ^ (rng << 5);
      v[32*w +: 32] = rng;
    end
  endtask

  // Vetores da FIPS-197:
  // Cifragem: rodadas 1..10 (indice 0..9):
  
  logic [127:0] b_start [10];
  logic [127:0] b_sub [10];
  logic [127:0] b_shift [10];
  logic [127:0] b_mix [9]; // rodadas 1..9 (a rodada 10 nao tem MixColumns)
  
  // AddRoundKey: entrada, chave e saida (11 passos: rodada 0 a 10):
  logic [127:0] ark_v_in  [11];
  logic [127:0] ark_v_key [11];
  logic [127:0] ark_v_out [11];
  
  // Cifragem inversa: rodadas 10..1 (indice 0..9):
  logic [127:0] c_start [10];
  logic [127:0] c_row [10];
  logic [127:0] c_box [10];
  logic [127:0] c_key [10];
  logic [127:0] c_add [10];
  logic [127:0] c_mix [9]; // saida do InvMixColumns das rodadas 10..2

  initial begin

    b_start[0] = 128'h193de3bea0f4e22b9ac68d2ae9f84808; b_sub[0] = 128'hd42711aee0bf98f1b8b45de51e415230; b_shift[0] = 128'hd4bf5d30e0b452aeb84111f11e2798e5; b_mix[0] = 128'h046681e5e0cb199a48f8d37a2806264c;
    b_start[1] = 128'ha49c7ff2689f352b6b5bea43026a5049; b_sub[1] = 128'h49ded28945db96f17f39871a7702533b; b_shift[1] = 128'h49db873b453953897f02d2f177de961a; b_mix[1] = 128'h584dcaf11b4b5aacdbe7caa81b6bb0e5;
    b_start[2] = 128'haa8f5f0361dde3ef82d24ad26832469a; b_sub[2] = 128'hac73cf7befc111df13b5d6b545235ab8; b_shift[2] = 128'hacc1d6b8efb55a7b1323cfdf457311b5; b_mix[2] = 128'h75ec0993200b633353c0cf7cbb25d0dc;
    b_start[3] = 128'h486c4eee671d9d0d4de3b138d65f58e7; b_sub[3] = 128'h52502f2885a45ed7e311c807f6cf6a94; b_shift[3] = 128'h52a4c89485116a28e3cf2fd7f6505e07; b_mix[3] = 128'h0fd6daa9603138bf6fc0106b5eb31301;
    b_start[4] = 128'he0927fe8c86363c0d9b1355085b8be01; b_sub[4] = 128'he14fd29be8fbfbba35c89653976cae7c; b_shift[4] = 128'he1fb967ce8c8ae9b356cd2ba974ffb53; b_mix[4] = 128'h25d1a9adbd11d168b63a338e4c4cc0b0;
    b_start[5] = 128'hf1006f55c1924cef7cc88b325db5d50c; b_sub[5] = 128'ha163a8fc784f29df10e83d234cd503fe; b_shift[5] = 128'ha14f3dfe78e803fc10d5a8df4c632923; b_mix[5] = 128'h4b868d6d2c4a8980339df4e837d218d8;
    b_start[6] = 128'h260e2e173d41b77de86472a9fdd28b25; b_sub[6] = 128'hf7ab31f02783a9ff9b4340d354b53d3f; b_shift[6] = 128'hf783403f27433df09bb531ff54aba9d3; b_mix[6] = 128'h1415b5bf461615ec274656d7342ad843;
    b_start[7] = 128'h5a4142b11949dc1fa3e019657a8c040c; b_sub[7] = 128'hbe832cc8d43b86c00ae1d44dda64f2fe; b_shift[7] = 128'hbe3bd4fed4e1f2c80a642cc0da83864d; b_mix[7] = 128'h00512fd1b1c889ff54766dcdfa1b99ea;
    b_start[8] = 128'hea835cf00445332d655d98ad8596b0c5; b_sub[8] = 128'h87ec4a8cf26ec3d84d4c46959790e7a6; b_shift[8] = 128'h876e46a6f24ce78c4d904ad897ecc395; b_mix[8] = 128'h473794ed40d4e4a5a3703aa64c9f42bc;
    b_start[9] = 128'heb40f21e592e38848ba113e71bc342d2; b_sub[9] = 128'he9098972cb31075f3d327d94af2e2cb5; b_shift[9] = 128'he9317db5cb322c723d2e895faf090794;
    ark_v_in[0] = 128'h3243f6a8885a308d313198a2e0370734; ark_v_key[0] = 128'h2b7e151628aed2a6abf7158809cf4f3c; ark_v_out[0] = 128'h193de3bea0f4e22b9ac68d2ae9f84808;
    ark_v_in[1] = 128'h046681e5e0cb199a48f8d37a2806264c; ark_v_key[1] = 128'ha0fafe1788542cb123a339392a6c7605; ark_v_out[1] = 128'ha49c7ff2689f352b6b5bea43026a5049;
    ark_v_in[2] = 128'h584dcaf11b4b5aacdbe7caa81b6bb0e5; ark_v_key[2] = 128'hf2c295f27a96b9435935807a7359f67f; ark_v_out[2] = 128'haa8f5f0361dde3ef82d24ad26832469a;
    ark_v_in[3] = 128'h75ec0993200b633353c0cf7cbb25d0dc; ark_v_key[3] = 128'h3d80477d4716fe3e1e237e446d7a883b; ark_v_out[3] = 128'h486c4eee671d9d0d4de3b138d65f58e7;
    ark_v_in[4] = 128'h0fd6daa9603138bf6fc0106b5eb31301; ark_v_key[4] = 128'hef44a541a8525b7fb671253bdb0bad00; ark_v_out[4] = 128'he0927fe8c86363c0d9b1355085b8be01;
    ark_v_in[5] = 128'h25d1a9adbd11d168b63a338e4c4cc0b0; ark_v_key[5] = 128'hd4d1c6f87c839d87caf2b8bc11f915bc; ark_v_out[5] = 128'hf1006f55c1924cef7cc88b325db5d50c;
    ark_v_in[6] = 128'h4b868d6d2c4a8980339df4e837d218d8; ark_v_key[6] = 128'h6d88a37a110b3efddbf98641ca0093fd; ark_v_out[6] = 128'h260e2e173d41b77de86472a9fdd28b25;
    ark_v_in[7] = 128'h1415b5bf461615ec274656d7342ad843; ark_v_key[7] = 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f; ark_v_out[7] = 128'h5a4142b11949dc1fa3e019657a8c040c;
    ark_v_in[8] = 128'h00512fd1b1c889ff54766dcdfa1b99ea; ark_v_key[8] = 128'head27321b58dbad2312bf5607f8d292f; ark_v_out[8] = 128'hea835cf00445332d655d98ad8596b0c5;
    ark_v_in[9] = 128'h473794ed40d4e4a5a3703aa64c9f42bc; ark_v_key[9] = 128'hac7766f319fadc2128d12941575c006e; ark_v_out[9] = 128'heb40f21e592e38848ba113e71bc342d2;
    ark_v_in[10] = 128'he9317db5cb322c723d2e895faf090794; ark_v_key[10] = 128'hd014f9a8c9ee2589e13f0cc8b6630ca6; ark_v_out[10] = 128'h3925841d02dc09fbdc118597196a0b32;
    c_start[0] = 128'h7ad5fda789ef4e272bca100b3d9ff59f; c_row[0] = 128'h7a9f102789d5f50b2beffd9f3dca4ea7; c_box[0] = 128'hbd6e7c3df2b5779e0b61216e8b10b689; c_key[0] = 128'h549932d1f08557681093ed9cbe2c974e; c_add[0] = 128'he9f74eec023020f61bf2ccf2353c21c7; c_mix[0] = 128'h54d990a16ba09ab596bbf40ea111702f;
    c_start[1] = 128'h54d990a16ba09ab596bbf40ea111702f; c_row[1] = 128'h5411f4b56bd9700e96a0902fa1bb9aa1; c_box[1] = 128'hfde3bad205e5d0d73547964ef1fe37f1; c_key[1] = 128'h47438735a41c65b9e016baf4aebf7ad2; c_add[1] = 128'hbaa03de7a1f9b56ed5512cba5f414d23; c_mix[1] = 128'h3e1c22c0b6fcbf768da85067f6170495;
    c_start[2] = 128'h3e1c22c0b6fcbf768da85067f6170495; c_row[2] = 128'h3e175076b61c04678dfc2295f6a8bfc0; c_box[2] = 128'hd1876c0f79c4300ab45594add66ff41f; c_key[2] = 128'h14f9701ae35fe28c440adf4d4ea9c026; c_add[2] = 128'hc57e1c159a9bd286f05f4be098c63439; c_mix[2] = 128'hb458124c68b68a014b99f82e5f15554c;
    c_start[3] = 128'hb458124c68b68a014b99f82e5f15554c; c_row[3] = 128'hb415f8016858552e4bb6124c5f998a4c; c_box[3] = 128'hc62fe109f75eedc3cc79395d84f9cf5d; c_key[3] = 128'h5e390f7df7a69296a7553dc10aa31f6b; c_add[3] = 128'h9816ee7400f87f556b2c049c8e5ad036; c_mix[3] = 128'he8dab6901477d4653ff7f5e2e747dd4f;
    c_start[4] = 128'he8dab6901477d4653ff7f5e2e747dd4f; c_row[4] = 128'he847f56514dadde23f77b64fe7f7d490; c_box[4] = 128'hc81677bc9b7ac93b25027992b0261996; c_key[4] = 128'h3caaa3e8a99f9deb50f3af57adf622aa; c_add[4] = 128'hf4bcd45432e554d075f1d6c51dd03b3c; c_mix[4] = 128'h36339d50f9b539269f2c092dc4406d23;
    c_start[5] = 128'h36339d50f9b539269f2c092dc4406d23; c_row[5] = 128'h36400926f9336d2d9fb59d23c42c3950; c_box[5] = 128'h247240236966b3fa6ed2753288425b6c; c_key[5] = 128'h47f7f7bc95353e03f96c32bcfd058dfd; c_add[5] = 128'h6385b79ffc538df997be478e7547d691; c_mix[5] = 128'h2d6d7ef03f33e334093602dd5bfb12c7;
    c_start[6] = 128'h2d6d7ef03f33e334093602dd5bfb12c7; c_row[6] = 128'h2dfb02343f6d12dd09337ec75b36e3f0; c_box[6] = 128'hfa636a2825b339c940668a3157244d17; c_key[6] = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41; c_add[6] = 128'h4c9c1e66f771f0762c3f868e534df256; c_mix[6] = 128'h3bd92268fc74fb735767cbe0c0590e2d;
    c_start[7] = 128'h3bd92268fc74fb735767cbe0c0590e2d; c_row[7] = 128'h3b59cb73fcd90ee05774222dc067fb68; c_box[7] = 128'h4915598f55e5d7a0daca94fa1f0a63f7; c_key[7] = 128'hb692cf0b643dbdf1be9bc5006830b3fe; c_add[7] = 128'hff87968431d86a51645151fa773ad009; c_mix[7] = 128'ha7be1a6997ad739bd8c9ca451f618b61;
    c_start[8] = 128'ha7be1a6997ad739bd8c9ca451f618b61; c_row[8] = 128'ha761ca9b97be8b45d8ad1a611fc97369; c_box[8] = 128'h89d810e8855ace682d1843d8cb128fe4; c_key[8] = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe; c_add[8] = 128'h5f72641557f5bc92f7be3b291db9f91a; c_mix[8] = 128'h6353e08c0960e104cd70b751bacad0e7;
    c_start[9] = 128'h6353e08c0960e104cd70b751bacad0e7; c_row[9] = 128'h63cab7040953d051cd60e0e7ba70e18c; c_box[9] = 128'h00102030405060708090a0b0c0d0e0f0; c_key[9] = 128'h000102030405060708090a0b0c0d0e0f; c_add[9] = 128'h00112233445566778899aabbccddeeff;
  end

  // Contadores e utilitarios de verificacao:

  int errors;
  int checks;
  int tick;

  task automatic settle();
    #1 tick = tick + 1;
  endtask

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
      $error("[FAIL] %s:\n obtido  =%032h\n esperado=%032h", name, got, exp);
    end
  endtask

  // Estimulos:

  int e0;
  logic [127:0] x;

  initial begin
    errors = 0;
    checks = 0;
    tick = 0;
    rng = 32'h1badb002;
    x = '0;
    sbox_in = '0; isbox_in = '0;
    sb_in = '0; sr_in = '0; mc_in = '0; ark_in = '0; ark_key = '0;
    isb_in = '0; isr_in = '0; imc_in = '0;
    settle();

    // Tabelas de referencia: ref_sbox[x] = sbox_ref(x) e ref_inv[ref_sbox[x]] = x:
    for (int i = 0; i < 256; i++) ref_sbox[i] = sbox_ref(i[7:0]);
    for (int i = 0; i < 256; i++) ref_inv[ref_sbox[i]] = i[7:0];

    // (1) S-box e S-box inversa: 256 entradas:
    e0 = errors;
    for (int i = 0; i < 256; i++) begin
      sbox_in = i[7:0];
      isbox_in = i[7:0];
      settle();
      check8($sformatf("sbox(%02h)", i[7:0]), sbox_out, ref_sbox[i]);
      check8($sformatf("inv_sbox(%02h)", i[7:0]), isbox_out, ref_inv[i]);
    end
    sbox_in = 8'h00; settle(); check8("sbox(00) FIPS-197", sbox_out, 8'h63);
    sbox_in = 8'h53; settle(); check8("sbox(53) FIPS-197", sbox_out, 8'hed);
    isbox_in = 8'h63; settle(); check8("inv_sbox(63) FIPS-197", isbox_out, 8'h00);
    isbox_in = 8'hed; settle(); check8("inv_sbox(ed) FIPS-197", isbox_out, 8'h53);
    $display("[INFO] (1) S-box e S-box inversa (256 entradas): %0d erro(s)", errors - e0);

    // (2) Cifragem:
    e0 = errors;
    for (int r = 0; r < 10; r++) begin
      sb_in = b_start[r];
      sr_in = b_sub[r];
      settle();
      check128($sformatf("SubBytes rodada %0d", r + 1), sb_out, b_sub[r]);
      check128($sformatf("ShiftRows rodada %0d", r + 1), sr_out, b_shift[r]);
    end
    for (int r = 0; r < 9; r++) begin
      mc_in = b_shift[r];
      settle();
      check128($sformatf("MixColumns rodada %0d", r + 1), mc_out, b_mix[r]);
    end
    for (int r = 0; r < 11; r++) begin
      ark_in = ark_v_in[r];
      ark_key = ark_v_key[r];
      settle();
      check128($sformatf("AddRoundKey passo %0d", r), ark_out, ark_v_out[r]);
    end
    $display("[INFO] (2) SubBytes, ShiftRows, MixColumns, AddRoundKey: %0d erro(s)", errors - e0);

    // (3) Cifragem inversa:
    e0 = errors;
    for (int i = 0; i < 10; i++) begin
      isr_in = c_start[i];
      isb_in = c_row[i];
      ark_in = c_box[i];
      ark_key = c_key[i];
      settle();
      check128($sformatf("InvShiftRows rodada %0d", 10 - i), isr_out, c_row[i]);
      check128($sformatf("InvSubBytes rodada %0d", 10 - i), isb_out, c_box[i]);
      check128($sformatf("AddRoundKey rodada %0d (inversa)", 10 - i), ark_out, c_add[i]);
    end
    for (int i = 0; i < 9; i++) begin
      imc_in = c_add[i];
      settle();
      check128($sformatf("InvMixColumns rodada %0d", 10 - i), imc_out, c_mix[i]);
    end
    $display("[INFO] (3) InvShiftRows, InvSubBytes, InvMixColumns, AddRoundKey: %0d erro(s)", errors - e0);

    // (4) Propriedades de inversa e (5) modelo de referencia:
    e0 = errors;
    for (int n = 0; n < N_RAND; n++) begin
      next_rand(x);

      sb_in = x; settle(); isb_in = sb_out;  settle();
      check128($sformatf("InvSubBytes(SubBytes(x)) n=%0d", n), isb_out, x);

      sr_in = x; settle(); isr_in = sr_out;  settle();
      check128($sformatf("InvShiftRows(ShiftRows(x)) n=%0d", n), isr_out, x);

      mc_in = x; settle(); imc_in = mc_out;  settle();
      check128($sformatf("InvMixColumns(MixColumns(x)) n=%0d", n), imc_out, x);

      ark_in = x; ark_key = {x[63:0], x[127:64]};  settle();
      ark_in = ark_out; settle();
      check128($sformatf("AddRoundKey(AddRoundKey(x,k),k) n=%0d", n), ark_out, x);

      mc_in = x; imc_in = x; settle();
      check128($sformatf("MixColumns vs referencia n=%0d", n), mc_out,  mix_ref(x, 1'b0));
      check128($sformatf("InvMixColumns vs referencia n=%0d", n), imc_out, mix_ref(x, 1'b1));
    end
    $display("[INFO] (4)+(5) Propriedades de inversa e referencia (%0d vetores): %0d erro(s)",
             N_RAND, errors - e0);

    // Resultado final:
    $display("--------------------------------------------------");
    if (errors == 0) begin
      $display("PASS: %0d verificacoes, 0 erros", checks);
      $finish;
    end else begin
      $display("FAIL: %0d verificacoes, %0d erro(s)", checks, errors);
      $fatal(1, "minisoc_aes_transforms_tb falhou");
    end
  end

endmodule
