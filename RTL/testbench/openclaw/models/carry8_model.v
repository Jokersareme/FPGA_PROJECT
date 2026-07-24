`timescale 1ns / 1ps
`timescale 1ns / 1ps
// CARRY8 行为模型 — 每级 5ps 延迟
// CO[tap] = S[tap] ? CO[tap-1] : DI[tap]
// 每级传播延迟 = 5ps
module CARRY8 #(parameter CARRY_TYPE="SINGLE_CY8")(
    output reg [7:0] CO, output [7:0] O,
    input [7:0] CI_TOP, input [7:0] DI, input [7:0] S, input CI);
    initial CO = 0;
    always @(*) begin
        CO[0] <= #0.020 (S[0]) ? CI      : DI[0];
        CO[1] <= #0.020 (S[1]) ? CO[0]   : DI[1];
        CO[2] <= #0.020 (S[2]) ? CO[1]   : DI[2];
        CO[3] <= #0.020 (S[3]) ? CO[2]   : DI[3];
        CO[4] <= #0.020 (S[4]) ? CO[3]   : DI[4];
        CO[5] <= #0.020 (S[5]) ? CO[4]   : DI[5];
        CO[6] <= #0.020 (S[6]) ? CO[5]   : DI[6];
        CO[7] <= #0.020 (S[7]) ? CO[6]   : DI[7];
    end
    assign O = 8'b0;
endmodule
