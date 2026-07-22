`timescale  1ns / 1ps

// ????????? Sigma-Delta ????????????????????? P ???? S ???
module calculate_ps #(
    parameter P_WIDTH = 6,
    parameter S_WIDTH = 2,
    parameter INT_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,

    input wire [INT_WIDTH-1:0] Integer,  // ????

    input wire [3:0] delta_sigma,        // Sigma-Delta ??????

    input wire [9:0] Ei,        // Sigma-Delta ??????
	
    output wire [S_WIDTH-1:0] Si,
    output wire [P_WIDTH-1:0] Pi,
	
    output reg [9:0] Eo        // Sigma-Delta ??????
);

    reg [INT_WIDTH-1:0] real_integer = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            real_integer <= Integer;
			Eo <= 0;
        end else begin
            real_integer <= Integer + {{(INT_WIDTH-4){delta_sigma[3]}}, delta_sigma};
//            real_integer <= Integer + {{(INT_WIDTH-4){delta_sigma[3]}}, delta_sigma};
			Eo <= Ei;
        end
    end

    //assign Pi = real_integer[INT_WIDTH-1:INT_WIDTH-P_WIDTH];
	assign Pi = real_integer >> 2;
    assign Si = real_integer[S_WIDTH-1:0];
    
endmodule