// File: enc2chan.sv
// Description: ELEX 7660 lab3 - Receives encoder inputs and selects ADC channel
// Author: Ryan McKay 
// Date: 2024-02-01

//8 channels 0 - 7

module enc2chan	( input logic cw, ccw, // outputs from lab 2 encoder module
						  output logic [2:0] chan, // desired channel
						  input logic reset_n, clk); // reset and clock
						  
				
		//Increment or decrement count based on encoder inputs
		always_ff@(posedge clk, negedge reset_n) begin
			if(~reset_n) begin
				chan <= 0 ;
			end				
			else begin			
				if (cw)
					chan <= chan + 1 ;
				
				else if (ccw) 
					chan <= chan - 1 ;	
			end		
		end
						  
endmodule