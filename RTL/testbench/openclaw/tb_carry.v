	imescale 1ns / 1ps
module tb_carry;
    reg ci = 0;
    wire [7:0] co;
    CARRY8 #(.CARRY_TYPE("SINGLE_CY8")) uut (
        .CO(co), .O(), .CI_TOP(8'b0), .DI(8'b0), .S(8'hFF), .CI(ci));
    initial begin
        ("%0t: CI=%b CO=%b", , ci, co);
        #5 ci = 1;
        #5 ci = 0;
        #5 ;
    end
endmodule
