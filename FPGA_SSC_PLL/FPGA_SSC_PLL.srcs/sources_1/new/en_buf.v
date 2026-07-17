`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/17 11:09:37
// Design Name: 
// Module Name: en_buf
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// 方案 1：普通逻辑使能（数据通路）
(* DONT_TOUCH = "TRUE" *)
module en_buf (
    output wire O,
    input  wire I0,      
    input  wire EN      // codei 接这里
);
    assign O = EN ? I0 : 1'b0;
endmodule