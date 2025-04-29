//File: decode7.sv
// Description: ELEX 7660 lab1 decodes 4 bit input 'idnums' to 8 bit output 'leds',
//					 converts binary numbers to binary values controlling each segment of display.
//	Modified to place a decimal instead of show letters - unused in current iteration of project


module decode7 (input logic [3:0] num,
					 output logic [7:0] leds) ;
					 
	always_comb
    case (num)
        4'h0 : leds = 8'b0011_1111 ; // 0x3F
        4'h1 : leds = 8'b0000_0110 ; // 0x06
        4'h2 : leds = 8'b0101_1011 ; // 0x5B
        4'h3 : leds = 8'b0100_1111 ; // 0x4F
        4'h4 : leds = 8'b0110_0110 ; // 0x66
        4'h5 : leds = 8'b0110_1101 ; // 0x6D
        4'h6 : leds = 8'b0111_1101 ; // 0x7D
        4'h7 : leds = 8'b0000_0111 ; // 0x07
        4'h8 : leds = 8'b0111_1111 ; // 0x7F
        4'h9 : leds = 8'b0110_1111 ; // 0x6F
        4'hA : leds = 8'b1011_1111 ; // 0.
        4'hB : leds = 8'b1000_0110 ; // 1.
        4'hC : leds = 8'b1101_1011 ; // 2.
        4'hD : leds = 8'b1100_1111 ; // 3.
        4'hE : leds = 8'b1110_0110 ; // 4.
        4'hF : leds = 8'b0000_0000 ; 
        default: leds = 8'h00 ;      // 0x00, all segments off
    endcase
		
					 
endmodule