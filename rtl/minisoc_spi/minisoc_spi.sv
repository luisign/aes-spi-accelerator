module minisoc_spi #(
  parameter logic [31:0] VERSION_VALUE = 32'h0001_0000 // v1.0.0
) (
  input logic clk, // clock (2 GHz)
  input logic rst_n,

  // Interface SPI:
  input logic spi_sclk,
  input logic spi_cs_n,
  input logic spi_mosi,
  output logic spi_miso,

  // Configuracao do AES (dominio do clk):
  output logic [127:0] cfg_key_o, // {KEY0, KEY1, KEY2, KEY3}
  output logic [127:0] cfg_iv_o, // {IV0, IV1, IV2, IV3}
  output logic [63:0] cfg_counter_o, // {COUNTER_HI, COUNTER_LO}
  output logic [31:0] cfg_num_blocks_o,
  output logic [2:0] cfg_mode_o,
  output logic cfg_decrypt_o,
  output logic aes_start_o, // pulso de 1 ciclo de clk

  // Controle do sistema (dominio do clk):
  output logic mem_sel_aes_o,
  output logic pll_enable_o,
  output logic [1:0] pll_div_sel_o,

  // Status (dominio do clk):
  input logic aes_busy_i,
  input logic aes_done_i,
  input logic aes_error_i,
  input logic [8:0] aes_blocks_done_i,
  input logic pll_locked_i
);

  // Mapa de enderecos (secao 6):
  localparam logic [5:0] ADDR_KEY0 = 6'h00;
  localparam logic [5:0] ADDR_KEY1 = 6'h01;
  localparam logic [5:0] ADDR_KEY2 = 6'h02;
  localparam logic [5:0] ADDR_KEY3 = 6'h03;
  localparam logic [5:0] ADDR_IV0 = 6'h04;
  localparam logic [5:0] ADDR_IV1 = 6'h05;
  localparam logic [5:0] ADDR_IV2 = 6'h06;
  localparam logic [5:0] ADDR_IV3 = 6'h07;
  localparam logic [5:0] ADDR_COUNTER_HI = 6'h08;
  localparam logic [5:0] ADDR_COUNTER_LO = 6'h09;
  localparam logic [5:0] ADDR_NUM_BLOCKS = 6'h0A;
  localparam logic [5:0] ADDR_AES_CTRL = 6'h0B;
  localparam logic [5:0] ADDR_AES_STATUS = 6'h0C;
  localparam logic [5:0] ADDR_VERSION = 6'h0D;
  localparam logic [5:0] ADDR_SYS_CTRL = 6'h0E;
  localparam logic [5:0] ADDR_SYS_STATUS = 6'h0F;
  localparam logic [5:0] ADDR_NOP = 6'h3F;

  // Dominio spi_sclk: recepcao serial e saida MISO:
  logic [39:0] rx_shift_q; // deslocador de entrada
  logic [5:0] bit_cnt_q; // bordas de subida recebidas neste frame (0 a 40)
  logic [39:0] frame_hold_q; // ultimo frame completo
  logic frame_tog_q; // inverte a cada frame completo
  logic [31:0] rd_hold_q; // instantaneo do registrador lido (escrito em clk)

  // Contador de bits e deslocador:
  always_ff @(posedge spi_sclk or negedge rst_n or posedge spi_cs_n) begin
    if (!rst_n) begin
      bit_cnt_q <= 6'd0;
      rx_shift_q <= 40'd0;
    end else if (spi_cs_n) begin
      bit_cnt_q <= 6'd0;
    end else if (bit_cnt_q < 6'd40) begin
      rx_shift_q <= {rx_shift_q[38:0], spi_mosi};
      bit_cnt_q <= bit_cnt_q + 6'd1;
    end
  end

  // Frame completo: no bit 40, guarda o frame e inverte o toggle:
  always_ff @(posedge spi_sclk or negedge rst_n) begin
    if (!rst_n) begin
      frame_hold_q <= 40'd0;
      frame_tog_q <= 1'b0;
    end else if (!spi_cs_n && bit_cnt_q == 6'd39) begin
      frame_hold_q <= {rx_shift_q[38:0], spi_mosi};
      frame_tog_q <= ~frame_tog_q;
    end
  end

  // MISO: atualizado na borda de descida. Nos 8 primeiros bits (RWb, ADDR, RSV) vale 0 e nos 32 ultimos desloca rd_hold_q, mas so se ADDR = 0x3F (NOP):
  logic nop_q; // o frame em curso tem ADDR = NOP
  logic nop_now;

  assign nop_now = (rx_shift_q[6:1] == ADDR_NOP); // valido quando bit_cnt_q = 8

  always_ff @(negedge spi_sclk or negedge rst_n or posedge spi_cs_n) begin
    if (!rst_n) begin
      spi_miso <= 1'b0;
      nop_q <= 1'b0;
    end else if (spi_cs_n) begin
      spi_miso <= 1'b0;
      nop_q <= 1'b0;
    end else begin
      if (bit_cnt_q == 6'd8) begin
        nop_q <= nop_now;
        spi_miso <= nop_now ? rd_hold_q[31] : 1'b0;
      end else if (bit_cnt_q > 6'd8 && bit_cnt_q <= 6'd39) begin
        spi_miso <= nop_q ? rd_hold_q[6'd39 - bit_cnt_q] : 1'b0;
      end else begin
        spi_miso <= 1'b0;
      end
    end
  end

  // Dominio do clk: sincronizacao do toggle e banco de registradores:
  logic tog_s1_q, tog_s2_q, tog_s3_q;
  logic frame_valid; // 1 ciclo de clock por frame completo

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tog_s1_q <= 1'b0;
      tog_s2_q <= 1'b0;
      tog_s3_q <= 1'b0;
    end else begin
      tog_s1_q <= frame_tog_q;
      tog_s2_q <= tog_s1_q;
      tog_s3_q <= tog_s2_q;
    end
  end

  assign frame_valid = tog_s2_q ^ tog_s3_q;

  // Campos do frame:
  logic f_rwb;
  logic [5:0] f_addr;
  logic f_rsv;
  logic [31:0] f_data;

  assign f_rwb = frame_hold_q[39];
  assign f_addr = frame_hold_q[38:33];
  assign f_rsv = frame_hold_q[32];
  assign f_data = frame_hold_q[31:0];

  // Registradores:
  logic [127:0] key_q;
  logic [127:0] iv_q;
  logic [31:0] counter_hi_q;
  logic [31:0] counter_lo_q;
  logic [31:0] num_blocks_q;
  logic [2:0] mode_q;
  logic decrypt_q;
  logic mem_sel_q;
  logic pll_enable_q;
  logic [1:0] pll_div_sel_q;
  logic aes_start_q;

  // Leitura de um registrador:
  function automatic logic [31:0] reg_read(input logic [5:0] a);
    case (a)
      ADDR_KEY0: return key_q[127:96];
      ADDR_KEY1: return key_q[95:64];
      ADDR_KEY2: return key_q[63:32];
      ADDR_KEY3: return key_q[31:0];
      ADDR_IV0: return iv_q[127:96];
      ADDR_IV1: return iv_q[95:64];
      ADDR_IV2: return iv_q[63:32];
      ADDR_IV3: return iv_q[31:0];
      ADDR_COUNTER_HI: return counter_hi_q;
      ADDR_COUNTER_LO: return counter_lo_q;
      ADDR_NUM_BLOCKS: return num_blocks_q;
      ADDR_AES_CTRL: return {27'd0, mode_q, decrypt_q, 1'b0}; // START le 0
      ADDR_AES_STATUS: return {20'd0, aes_blocks_done_i, aes_error_i, aes_done_i, aes_busy_i};
      ADDR_VERSION: return VERSION_VALUE;
      ADDR_SYS_CTRL: return {28'd0, pll_div_sel_q, pll_enable_q, mem_sel_q};
      ADDR_SYS_STATUS: return {31'd0, pll_locked_i};
      default: return 32'd0; // nao mapeado
    endcase
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      key_q <= 128'd0;
      iv_q <= 128'd0;
      counter_hi_q <= 32'd0;
      counter_lo_q <= 32'd0;
      num_blocks_q <= 32'd0;
      mode_q <= 3'd0;
      decrypt_q <= 1'b0;
      mem_sel_q <= 1'b0;
      pll_enable_q <= 1'b0;
      pll_div_sel_q <= 2'd0;
      aes_start_q <= 1'b0;
      rd_hold_q <= 32'd0;
    end else begin
      aes_start_q <= 1'b0; // START e um pulso de 1 ciclo

      if (frame_valid && !f_rsv && f_addr != ADDR_NOP) begin
        if (f_rwb) begin
          // Pedido de leitura: guarda o instantaneo para a transacao seguinte:
          rd_hold_q <= reg_read(f_addr);
        end else begin
          // Escrita (registradores somente leitura e enderecos nao mapeados sao ignorados):
          case (f_addr)
            ADDR_KEY0: key_q[127:96] <= f_data;
            ADDR_KEY1: key_q[95:64] <= f_data;
            ADDR_KEY2: key_q[63:32] <= f_data;
            ADDR_KEY3: key_q[31:0] <= f_data;
            ADDR_IV0: iv_q[127:96] <= f_data;
            ADDR_IV1: iv_q[95:64] <= f_data;
            ADDR_IV2: iv_q[63:32] <= f_data;
            ADDR_IV3: iv_q[31:0] <= f_data;
            ADDR_COUNTER_HI: counter_hi_q <= f_data;
            ADDR_COUNTER_LO: counter_lo_q <= f_data;
            ADDR_NUM_BLOCKS: num_blocks_q <= f_data;
            ADDR_AES_CTRL: begin
              mode_q <= f_data[4:2];
              decrypt_q <= f_data[1];
              aes_start_q <= f_data[0] && pll_locked_i; // write-one-pulse
            end
            ADDR_SYS_CTRL: begin
              mem_sel_q <= f_data[0];
              pll_enable_q <= f_data[1];
              pll_div_sel_q <= f_data[3:2];
            end
            default: begin end
          endcase
        end
      end
    end
  end

  // Saidas:
  assign cfg_key_o = key_q;
  assign cfg_iv_o = iv_q;
  assign cfg_counter_o = {counter_hi_q, counter_lo_q};
  assign cfg_num_blocks_o = num_blocks_q;
  assign cfg_mode_o = mode_q;
  assign cfg_decrypt_o = decrypt_q;
  assign aes_start_o = aes_start_q;
  assign mem_sel_aes_o = mem_sel_q;
  assign pll_enable_o = pll_enable_q;
  assign pll_div_sel_o = pll_div_sel_q;

endmodule
