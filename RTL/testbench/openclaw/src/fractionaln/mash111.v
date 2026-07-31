`timescale  1ns / 1ps

module mash111 #(
    parameter WIDTH = 24,  // ???????
    parameter A_GAIN = 1   // A = A_GAIN*2-1, ?????????????????
) (
    input clk,             // ????
    input clk_ila,             // ????
    input rst_n,           // ????????

    input [WIDTH-1:0] x_i, // Sigma-Delta ????????????????
    output reg [3:0] y_o,      // ????
    output [WIDTH-1:0] e_o
);

    wire [WIDTH-1:0] x_i_1;
    wire [WIDTH-1:0] e_o_1;
    wire y_o_1;
    wire [WIDTH-1:0] x_i_2;
    wire [WIDTH-1:0] e_o_2;
    wire y_o_2;
    wire [WIDTH-1:0] x_i_3;
    wire [WIDTH-1:0] e_o_3;
    wire y_o_3;
    
    
    reg y2_d = 0;
    reg y3_d = 0;
    reg y3_dd = 0;

    wire signed [2:0] c1;
    wire signed [3:0] c2;
    reg signed [0:0] c0_reg = 0;
    reg signed [2:0] c1_reg = 0; 

    wire [1:0] stage_sel;
    wire  mash_eo_mode;
    reg [WIDTH-1:0] eo_d1 = 0;

        
    // ??? efm ?????????? efm ???
    assign x_i_1 = x_i;
    assign x_i_2 = e_o_1;
    assign x_i_3 = e_o_2;

    // ? 3 ? efm ?????
    assign c1 = y_o_2 + y_o_3 - c0_reg;
    assign c2 = y_o_1 + {c1[2], c1} - {c1_reg[2], c1_reg}; // ?????

//    assign y_o = c2;

    // ???? EFM ??????? combiner
    assign e1_o = e_o_1;
    assign e2_o = e_o_2;
    assign e3_o = e_o_3;
    // ??????, ?? e_o (?? e1 ? 1 ???)
    assign e_o = eo_d1;

    // ??
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c0_reg <= 'b0;
            c1_reg <= 'b0;
            y2_d  <= 1'b0;
            y3_d  <= 1'b0;
            y3_dd <= 1'b0;
        end else begin
            c0_reg <= y_o_3;
            c1_reg <= c1;
            y2_d <= y_o_2;
            y3_d <= y_o_3;
            y3_dd <= y3_d;
        end 
    end
    
        always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            eo_d1 <= 1'b0;
			y_o <= 4'b0;
        end else begin
            eo_d1 <= e_o_1;
			y_o <=  (stage_sel == 2'b00) ? c2 :
					(stage_sel == 2'b01) ? y_o_1 :
					(stage_sel == 2'b10) ? y_o_1 + y_o_2 - y2_d : y_o_1 + y_o_2 - y2_d + (y_o_3 - y3_d - y3_d + y3_dd);
        end 
		end


    // ?? efm ??
    hk_efm #(
        .WIDTH ( WIDTH ),
        .A_GAIN(A_GAIN))
    u_hk_efm_1 (
        .clk                     ( clk     ),
        .rst_n                   ( rst_n   ),
        .x_i                     ( x_i_1   ),

        .y_o                     ( y_o_1   ),
        .e_o                     ( e_o_1   )
    );

    hk_efm #(
        .WIDTH ( WIDTH ),
        .A_GAIN(A_GAIN))
    u_hk_efm_2 (
        .clk                     ( clk     ),
        .rst_n                   ( rst_n   ),
        .x_i                     ( x_i_2   ),

        .y_o                     ( y_o_2   ),
        .e_o                     ( e_o_2   )
    );

    hk_efm #(
        .WIDTH ( WIDTH ),
        .A_GAIN(A_GAIN))
    u_hk_efm_3 (
        .clk                     ( clk     ),
        .rst_n                   ( rst_n   ),
        .x_i                     ( x_i_3   ),

        .y_o                     ( y_o_3   ),
        .e_o                     ( e_o_3   )
    );
//    assign stage_sel = 2'b01;
    mash_stage u_mash_stage (
        .clk (clk),
        .probe_out0 (stage_sel),
        .probe_out1 (mash_eo_mode)
    );
    
        ila_1 u_ila (
        .clk    (clk_ila),
        .probe0 (x_i_1),
        .probe1 (e_o_1),
        .probe2 (e_o_2),
        .probe3 (e_o_3),  // 3-bit ??? 4-bit ?? ILA ??????? ILA ????
        .probe4 (y_o)  // 3-bit ??? 4-bit ?? ILA ??????? ILA ????
    );
    
endmodule