`timescale 1ns/1ps

module tb_dummy;

    logic clk;
    logic rst;
    logic d;
    logic q;

    dummy u_dummy (
        .clk(clk),
        .rst(rst),
        .d(d),
        .q(q)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/dump.vcd");
        $dumpvars(0, tb_dummy);

        clk = 1'b0;
        rst = 1'b0;
        d = 1'b0;

        #15 rst = 1'b1;
        
        #10 d = 1'b1;
        #10 d = 1'b0;
        #10 d = 1'b1;

        #20;
        $display("Simulacao executada com sucesso");
        $finish;
    end

endmodule
