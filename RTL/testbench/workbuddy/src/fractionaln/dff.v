`timescale  1ns / 1ps

module dff (
    input clk,
    input LD,
    input rst_n,
    input P,
    input D,
    output reg Q = 0,
    output Qn
);
	
    always @(posedge clk or negedge rst_n or posedge LD) begin
		if (~rst_n) begin
			Q <= 1'b0;
		end else if (LD) begin
            Q <= P;
        end else begin
            Q <= D;
        end
    end
    
    assign Qn = ~Q;
    
endmodule