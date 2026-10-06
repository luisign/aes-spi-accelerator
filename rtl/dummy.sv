`timescale 1ns/1ps

module dummy (
    input logic clk,
    input logic rst,
    input logic d,
    output logic q
);

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            q <= 1'b0;
        end else begin
            q <= d;
        end
    end

endmodule
