// File: encoder.sv
// Description: ELEX 7660 lab2 - Receive encoder inputs and determine whether the 
// 										encoder is moving Clockwise or Counter-Clockwise
// Author: Ryan McKay 
// Date: 2024-01-22


module encoder ( input logic clk,	         // 50 MHz clock
					  input logic a, b,				// Encoder inputs
					  output logic cw, ccw ) ;

	
	logic [1:0] state_last ;
	logic signed [3:0] cnt ;
	logic clockwise, counterClockwise ;
	
	
	always_ff@(posedge clk) begin		
		
		cw <= 0 ;
		ccw <= 0 ;
		clockwise <= 0 ;
		counterClockwise <= 0 ;
		
		//Depending on last state + current state determine whether the encoder has been turned
		case({state_last, a, b})
			4'b0010, 4'b1011, 4'b1101, 4'b0100 : clockwise <= 1 ;
			4'b0001, 4'b0111, 4'b1110, 4'b1000 : counterClockwise <= 1 ;
		endcase
		
		// Updating count based on detected direction
		if(clockwise)
			cnt <= cnt + 1 ;
		else if (counterClockwise) 
			cnt <= cnt - 1 ;
			
		// Activate cw or ccw once four pulses have been received
		if (cnt > 3) begin
            cw <= 1 ;
            cnt <= 0 ; 
        end 
        else if (cnt < -3) begin
            ccw <= 1 ;
            cnt <= 0 ; 
        end
		
		state_last <= {a, b} ;
			
	end
	
						  
endmodule
					  