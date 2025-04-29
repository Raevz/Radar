// File: adcinterface.sv
// Description: ELEX 7660 lab4 - interface to the ltc2308 ADC
// Author: Ryan McKay 
// Date: 2024-02-07

module adcinterface(input logic clk, reset_n, // clock and reset
						  input logic [2:0] chan, // ADC channel to sample
						  output logic [11:0] result, // ADC result
							// ltc2308 signals
						  output logic ADC_CONVST, ADC_SCK, ADC_SDI,
						  input logic ADC_SDO ) ;
						  
	//states of adc interaction process
	typedef enum logic [2:0] { IDLE, START_CONV, WAIT_CONV, TRANSFER, DONE } state_t ;
	state_t state ;
	
	logic [11:0] adcoutput ;
	logic [5:0] configword, shift_word ;
	
	logic [3:0] pulse_cnt ;
	logic [1:0] wait_cnt ;
	logic SCK_START ;

	//Gate the ADC serial clock to only fire when transferring data					  
	assign ADC_SCK = (SCK_START) ? clk : 1'b0 ;	
		
	//Operation based on transfer state
	always_ff@(posedge clk, negedge reset_n) begin
		if(!reset_n) begin
			state <= IDLE ;
			configword <= 0 ;
			ADC_CONVST <= 0 ;
			adcoutput <= 0 ;
			result <= 0 ;
			SCK_START <= 1'b0 ;
		end
		else begin
			case(state)
			
				IDLE : begin
					ADC_CONVST <= 1'b0 ; //Ensure low convst
					wait_cnt <= 0 ;
					//Preload data into word for transfer into ADC_SDI
					case (chan)
						0 : configword <= 6'b100010 ;	//Channel 0
						1 : configword <= 6'b110010 ;	//Channel 1
						2 : configword <= 6'b100110 ;	//Channel 2
						3 : configword <= 6'b110110 ;	//...
						4 : configword <= 6'b101010 ; //...
						5 : configword <= 6'b111010 ;	//...
						6 : configword <= 6'b101110 ;	//...
						7 : configword <= 6'b111110 ;	//Channel 7
						default : configword <= configword ;
					endcase
					state <= START_CONV ;
				end
				
				START_CONV : begin
					ADC_CONVST <= 1'b1 ; //Activate convst bit
					state <= WAIT_CONV ;
				end
				
				WAIT_CONV : begin
					ADC_CONVST <= 1'b0 ; 					
					wait_cnt <= wait_cnt + 1'b1 ;
					pulse_cnt <= 0 ;
					
					//wait with convst bit low
					if (wait_cnt == 1)
						state <= TRANSFER ;				
				 end
				 
				 TRANSFER : begin
					
					if (pulse_cnt < 12) begin
					pulse_cnt <= pulse_cnt + 1'b1 ;
					SCK_START <= 1'b1 ;
					//Receive value from ADC
					adcoutput <= {adcoutput[10:0], ADC_SDO} ;
					end else begin
						SCK_START <= 1'b0 ;
						result <= adcoutput ;
						state <= DONE ;
					end
					
				 end
				 
				 DONE : begin	
					
					adcoutput <= '0 ;
					configword <= '0 ;
					state <= IDLE ;					
				 end
				endcase	
			end		
	end
	
	always_ff@(negedge clk) begin
		case(state)
		
			IDLE : ADC_SDI <= 1'b0 ;
		
			START_CONV : begin
				shift_word <= configword ;
			end
			
			WAIT_CONV : begin
				ADC_SDI <= shift_word[5] ;
				
			end
			
			TRANSFER: begin
				if (SCK_START) begin
					
					ADC_SDI <= shift_word[4] ;
					shift_word <= {shift_word[4:0], 1'b0} ;
					
				end
			end
			
		endcase	
	end	
endmodule