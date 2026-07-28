`timescale  1ns / 1ps

// ??????????????? mash111-Sigma-Delta ?????????
module fractionaln #(
    parameter P_WIDTH = 6,                  // P ??????
    parameter S_WIDTH = 2,                  // S ??????
    parameter INT_WIDTH = 8,                // ???????
    parameter FRAC_WIDTH = 10               // ???????
) (
    input wire Fin,                         // ????????
    input wire Sys_clk,                         // ????????
    input wire rst_n,                       // ????????

    input wire [INT_WIDTH-1:0] Integer,     // ??????
    input wire [FRAC_WIDTH-1:0] Fraction,   // ??????
    
    output reg [FRAC_WIDTH-1:0] Eo,          // 1 ??? (???)
    output reg [FRAC_WIDTH+1:0] E_combined,  // 3 ????? (?? 3 ? DTC ??)
    output wire Fout                         // ????
);

	wire rst_n_sync;
    wire [3:0] delta_sigma;
    wire clk_delta_sigma;
    wire [S_WIDTH-1:0] Si;
    wire [P_WIDTH-1:0] Pi;
    //reg Fout_reg;
    wire [FRAC_WIDTH-1:0] Eo_raw;

	reg signed [FRAC_WIDTH:0] sigma = 0;
	wire signed [FRAC_WIDTH:0] sigma_w;
	wire signed [FRAC_WIDTH:0] sigma_old;
	reg signed [FRAC_WIDTH:0] sigma_old_r = 0;

    // ??: Eo_raw (= e1[n-1]) ?? 1 ???,
    //       mash_e2/mash_e3 ?????, ??? 1 ???? e1
    reg [FRAC_WIDTH-1:0] Fraction_d1 = 0;                           // = e1[n-1]
    reg [FRAC_WIDTH-1:0] Fraction_d2 = 0;                           // = e1[n-1]
    reg [FRAC_WIDTH-1:0] Fraction_d3 = 0;                           // = e1[n-1]

    reg signed [FRAC_WIDTH+1:0] Ec_d1 = 0, Ec_d2 = 0, Ec_d3 = 0;            // E_combined ????

    assign clk_delta_sigma = Fout;
	reg [3:0] delta_sigma_d1 = 0;
	reg [3:0] delta_sigma_d2 = 0;
	wire y2_o;
	reg y2_o_d1 = 0;
	
	wire [1:0] eo_dly_sel;
	
	assign sigma_old = sigma_old_r + $signed(Fraction_d3) - $signed(delta_sigma) * $signed(13'sd1024);
	assign sigma_w = $signed({2'b00, Eo_raw}) - y2_o * $signed(12'sd1024);



    always @(negedge Fout or negedge rst_n) begin
        if (!rst_n) begin
            delta_sigma_d1 <= 0;
            delta_sigma_d2 <= 0;
            Ec_d1 <= 'd0; Ec_d2 <= 'd0; Ec_d3 <= 'd0;
            E_combined <= 'd0;
			sigma <= 'd0;
			sigma_old_r <= 'd0;
            Eo <= 'd0;
			Fraction_d1 <= 'd0;
			Fraction_d2 <= 'd0;
			Fraction_d3 <= 'd0;
			y2_o_d1 <= 'd0;
        end else begin
		
			
			Fraction_d1 <= Fraction;
			Fraction_d2 <= Fraction_d1;
			Fraction_d3 <= Fraction_d2;

            Eo <= Eo_raw;
            delta_sigma_d1 <= delta_sigma;
            delta_sigma_d2 <= delta_sigma_d1;
            y2_o_d1 <= y2_o;
			
			sigma <= sigma_w;
			sigma_old_r <= sigma_old;
            
 
            Ec_d1 <= sigma;
            Ec_d2 <= Ec_d1;
            Ec_d3 <= Ec_d2;
            // E_combined ???? (?? eo_dly_sel, ? Eo ????? VIO)
            E_combined <= (eo_dly_sel==2'b00) ? sigma :
                          (eo_dly_sel==2'b01) ? Ec_d1 :
                          (eo_dly_sel==2'b10) ? Ec_d2 : Ec_d3;
        end 
    end
    
    vio_eo u_vio_eo (
        .clk (Sys_clk),
        
        .probe_out0 (eo_dly_sel)
        );
        
    
    //assign Fout = Fout_reg;
    
	dff  u_sync_rstn_dff (
        .clk                     ( Fin      ),
        .LD                      ( 1'b0     ),
		.rst_n					 ( 1'b1		),
        .P                       ( 1'b1     ),
        .D                       ( rst_n    ),

        .Q                       ( rst_n_sync     ),
        .Qn                      (     )
    );

    // Sigma-Delta ??? (?????? EFM ????)
    mash111 #(
        .WIDTH  ( FRAC_WIDTH ),
        .A_GAIN ( 1  ))
    u_mash111 (
        .clk                     ( clk_delta_sigma ),
        .clk_ila                 ( Sys_clk         ),
        .rst_n                   ( rst_n_sync      ),
        .x_i                     ( Fraction_d1        ),

        .y_o                     ( delta_sigma     ),
        .y2_o                     ( y2_o     ),
        .e_o                     ( Eo_raw          )
    );

    // ????????? Sigma-Delta ????????????????????? P ???? S ???
    calculate_ps #(
        .P_WIDTH   ( P_WIDTH ),
        .S_WIDTH   ( S_WIDTH ),
        .INT_WIDTH ( INT_WIDTH ))
    u_calculate_ps (
        .clk                     ( ~clk_delta_sigma ),
        .rst_n                   ( rst_n_sync      ),
        .Integer                 ( Integer         ),
        .delta_sigma             ( delta_sigma_d1     ),
		.Ei						 ( Eo_raw		   ),
        .Si                      ( Si              ),
        .Pi                      ( Pi              ),
		.Eo						 (    		   )
    );
    
    // P/S ?????
    dual_div #(
        .P_WIDTH ( P_WIDTH ),
        .S_WIDTH ( S_WIDTH ))
    u_dual_div (
        .clk                     ( Fin        ),
        .clk_ila                 ( Sys_clk    ),
        .rst_n                   ( rst_n_sync ),
        .Si                      ( Si         ),
        .Pi                      ( Pi         ),

        .Fdiv                    ( Fout       )
    );    
    
endmodule