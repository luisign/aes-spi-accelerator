module minisoc_memory (
  input logic rst_n,
  input logic mem_sel_aes_i, // MEM_SEL_AES (0 = externa e 1 = AES)

  // Interface externa do MEMORY_DATA:
  input logic mem_clk,
  input logic [31:0] mem_i_data,
  input logic mem_i_wr_en, // 1 = escrita e 0 = leitura
  input logic [9:0] mem_i_addr,
  output logic [31:0] mem_o_data,

  // AES engine:
  input logic aes_clk, // sys_clk
  input logic [9:0] aes_addr_i,
  input logic [31:0] aes_wdata_i,
  input logic aes_we_i,
  output logic [31:0] aes_rdata_o,

  // Para depuracao e verificacao:
  output logic ext_own_o, // ramo externo
  output logic aes_own_o // ramo do AES
);

  // Mux de clock:
  logic ext_s1_q, ext_s2_q; // mem_sel_aes_i = 0 sincronizado em mem_clk
  logic aes_on_m1_q, aes_on_m2_q; // en_aes_lat sincronizado em mem_clk
  logic en_ext_q; // habilitacao do ramo externo (tambem mem_clk)

  logic aes_s1_q, aes_s2_q; // mem_sel_aes_i = 1 sincronizado em aes_clk
  logic ext_on_s1_q, ext_on_s2_q; // en_ext_lat sincronizado em aes_clk
  logic en_aes_q; // habilitacao do ramo do AES (sincronizado em aes_clk)
  logic en_ext_lat, en_aes_lat; // saidas dos latches de clock gating

  // Ramo externo (mem_clk):
  always_ff @(posedge mem_clk or negedge rst_n) begin
    if (!rst_n) begin
      ext_s1_q <= 1'b1;
      ext_s2_q <= 1'b1;
      aes_on_m1_q <= 1'b0;
      aes_on_m2_q <= 1'b0;
      en_ext_q <= 1'b1;
    end else begin
      ext_s1_q <= ~mem_sel_aes_i;
      ext_s2_q <= ext_s1_q;
      aes_on_m1_q <= en_aes_lat; // clock do ramo AES
      aes_on_m2_q <= aes_on_m1_q;
      en_ext_q <= ext_s2_q & ~aes_on_m2_q;
    end
  end

  // Ramo do AES (aes_clk):
  always_ff @(posedge aes_clk or negedge rst_n) begin
    if (!rst_n) begin
      aes_s1_q <= 1'b0;
      aes_s2_q <= 1'b0;
      ext_on_s1_q <= 1'b1;
      ext_on_s2_q <= 1'b1;
      en_aes_q <= 1'b0;
    end else begin
      aes_s1_q <= mem_sel_aes_i;
      aes_s2_q <= aes_s1_q;
      ext_on_s1_q <= en_ext_lat; // clock do ramo externo
      ext_on_s2_q <= ext_on_s1_q;
      en_aes_q <= aes_s2_q & ~ext_on_s2_q;
    end
  end

  // Clock gating de cada ramo:
  always_latch begin
    if (!mem_clk) en_ext_lat = en_ext_q;
  end

  always_latch begin
    if (!aes_clk) en_aes_lat = en_aes_q;
  end

  logic ram_clk;
  assign ram_clk = (mem_clk & en_ext_lat) | (aes_clk & en_aes_lat);

  assign ext_own_o = en_ext_q;
  assign aes_own_o = en_aes_q;

  // RAM:
  logic [9:0] ram_addr;
  logic [31:0] ram_wdata;
  logic ram_we;

  assign ram_addr = en_aes_q ? aes_addr_i : mem_i_addr;
  assign ram_wdata = en_aes_q ? aes_wdata_i : mem_i_data;
  assign ram_we = en_aes_q ? aes_we_i : mem_i_wr_en;

  // Matriz de memoria 1024 x 32:
  logic [31:0] mem_q [1024];
  logic [31:0] rdata_q;

  always_ff @(posedge ram_clk) begin
    if (ram_we) mem_q[ram_addr] <= ram_wdata;
    else rdata_q <= mem_q[ram_addr];
  end

  assign mem_o_data = rdata_q;
  assign aes_rdata_o = rdata_q;

endmodule
