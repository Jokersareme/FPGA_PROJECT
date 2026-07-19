`timescale  1ns / 1ps

module tb_fractionaln;

// fractionaln Parameters
parameter PERIOD      = 10;
parameter P_WIDTH     = 6 ;
parameter S_WIDTH     = 2 ;
parameter INT_WIDTH   = 8 ;
parameter FRAC_WIDTH  = 10;

// fractionaln Inputs
reg   Fin                                  = 0 ;
reg   rst_n                                = 0 ;
reg   [INT_WIDTH-1:0]  Integer             = 0 ;
reg   [FRAC_WIDTH-1:0]  Fraction           = 0 ;
reg clk=0;
reg clk_div=0;

// fractionaln Outputs
wire  Fout                                 ;
wire [FRAC_WIDTH-1:0] Eo;
wire Fdtc;

initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    forever #(PERIOD*71.208/2)  clk_div=~clk_div;
end

initial
begin
    #(PERIOD*10) rst_n  =  0;
    #(PERIOD*200) rst_n  =  1;
end

fractionaln #(
    .P_WIDTH    ( P_WIDTH    ),
    .S_WIDTH    ( S_WIDTH    ),
    .INT_WIDTH  ( INT_WIDTH  ),
    .FRAC_WIDTH ( FRAC_WIDTH ))
 u_fractionaln (
    .Fin                     ( clk                        ),
	.Sys_clk				 ( clk						  ),
    .rst_n                   ( rst_n                      ),
    .Integer                 ( Integer   				  ),
    .Fraction                ( Fraction  				  ),
	.Eo						 ( Eo		 				  ),
    .Fout                    ( Fout                       )
);

dtc_ideal #(
			.E_WIDTH 	 (FRAC_WIDTH),
			.DELAY_STEP	 (0.00977),
			.MAX_DELAY 	 (PERIOD)
) u_dtc (

	.in   (Fout)  , 
	.Eo   (Eo  )  ,
	.out  (Fdtc)  

);
				
				
				
initial
begin
	$dumpfile("fracn_div.vcd");      // 指定输出文件名
    $dumpvars(0, tb_fractionaln);
    Integer = 8'd71;
    //Fraction = 24'd8388607; // 2^23 - 1 (0.5)
	Fraction = 10'd213; // 2^23 - 1 (0.5)
    #(PERIOD*120*10000);
    $finish;
end

//integer dout_file;
//initial begin
//	$dumpfile("top.vcd");      // 指定输出文件名
//    $dumpvars(0, tb_fractionaln);
//    dout_file=$fopen("/home/EDA/vsim/Fractional-N-DIV/delta-sigma/tb/data.txt");    //打开所创建的文件
//    //if(dout_file == 0)begin 
//    //    $display ("can not open the file!");    //创建文件失败，显示can not open the file!
//    //    $stop;
//    end
//end

//always @(posedge u_fractionaln.u_mash111.clk) begin
//    $fdisplay(dout_file,"%d",$signed(u_fractionaln.u_mash111.y_o));    //保存有符号数据
//end   
// always @(posedge u_fractionaln.u_mash111.clk) begin
//     $fdisplay(dout_file,"%b",Fout);    //使能信号有效，每来一个时钟，写入到所创建的文件中
// end   

// /tb_fractionaln/u_fractionaln/u_mash111/y_o

endmodule