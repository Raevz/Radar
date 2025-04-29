//File: decode2.sv
// Description: ELEX 7660 lab1 decodes 2 bit input 'digit' to 4 bit output 'ct',
//					 controlling which digit is displayed.
// Author: Ryan McKay
// Date: 2024-01-14

module decode2 (input logic [1:0] digit,
					 output logic [3:0] ct) ;

	always_comb
		case (digit)
			2'b00 : ct = 4'b1110 ;
			2'b01 : ct = 4'b1101 ;
			2'b10 : ct = 4'b1011 ;
			2'b11 : ct = 4'b0111 ;
			default : ct = 4'b1111 ; //default to no leds selected
		endcase	

endmodule