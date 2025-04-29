// ============================================================================
// Project: Presence-Tracking Radar with Servo
// Top-level Module: servo
// Description: Connects radar detection and servo control to DE0-Nano GPIOs,
//					 exports angle and distance data over UART.
// Authors: Yizuo Chen && Ryan McKay
// Comment 1: When the module is NOT in MANUAL mode the behaviour is as follows.
//				SCAN until sensing an object within the trigger distance (selected by enc1 and displayed in centimeters) [green light]
//				LOCK upon detecting object within trigger range, freeze servo for 2 seconds. After 2 seconds move to WAIT_CLEAR [red light]
//				WAIT_CLEAR resume servo movement and continue until no longer detecting object in trigger range, move to SCAN [blue light]
//
// Comment 2: This module has an accompanying python module for receiving the angle + distance data and displaying 
//				  the radar output on a nice plot. 
// ============================================================================
module servo (
    // === Clock Input ===
    input  logic CLOCK_50,         // 50 MHz system clock

    // === Encoder Inputs ===
    (* altera_attribute = "-name WEAK_PULL_UP_RESISTOR ON" *)
    input  logic enc1_a, enc1_b,   // Encoder 1 signals

    (* altera_attribute = "-name WEAK_PULL_UP_RESISTOR ON" *)
    input  logic enc2_a, enc2_b,   // Encoder 2 signals

    // === Pushbuttons ===
    input  logic s1, s2,           // Active-low pushbuttons

    // === LED Display Outputs ===
    output logic [7:0] leds,       // LED indicators (7-seg)
    output logic [3:0] ct,         // Digit cathodes

    // === RGB Booster LEDs ===
    output logic red, green, blue, // Boosterpack LEDs

    // === General-Purpose I/O ===
    inout  logic [35:0] GPIO_0,
	 
	 // === ADC Signals ===
	 output logic ADC_CONVST, ADC_SCK, ADC_SDI, // ADC control signals
	 input logic ADC_SDO         					  // ADC data output
);

    // =========================================================================
    // === Internal Signals ===
    // =========================================================================
	 
	 // --- Servo signals ---
	 logic pwm_out;                // PWM signal to drive servo
	 logic [7:0]  angle;     		 // Current sweep angle (0–180°)
	 
	 // --- Radar signals ---
	 logic echo_in;                // Echo signal from radar (input)
    logic trig_out;               // Trigger signal to radar (output)
    logic pulse_alert;      		 // Pulse detection output
    logic alert_active;           // Alert state flag
	 logic [15:0] distance_cm;		 // Distance of presence from radar	 
	 logic [2:0] trig_choice;  	 // desired trigger distance
	 
	 // --- Encoder signals ---
	 logic [7:0] enc1_count; 		 // count used to track encoder movement and to display
    logic enc1_cw, enc1_ccw;  	 // encoder module outputs
	 
	 // --- ADC signals ---
	 logic ADC_clk ;					 //Select frequency for ADC interface
	 logic [4:0] adc_cnt ;
	 logic [11:0] result ; 		    // ADC result
	 
	 // --- Display signals ---
	 logic [15:0] disp_choice;		 // Show the trigger distance in decimal on the display
    logic [1:0] digit;  			 // select digit to display
    logic [3:0] disp_digit;  		 // current digit of count to display
    logic [15:0] clk_div_count;   // count used to divide clock	
	 logic [3:0] hundreds, tens, ones ; //Convert distance_cm into decimal	 

    // =========================================================================
    // === GPIO Assignments ===
    // =========================================================================
    assign GPIO_0[18] = pulse_alert;  		  // Output: suspicious pulse indicator - used for testing
    assign GPIO_0[22] = pwm_out;            // Output: PWM signal to servo
    assign echo_in    = GPIO_0[27];         // Input: echo signal from radar
    assign GPIO_0[21] = trig_out;           // Output: trigger to radar           - used for testing
    assign GPIO_0[20] = alert_active;       // Output: system alert state
	 assign GPIO_0[35] = uart_tx_pin;		  // Output: UART Tx Pin

    // Set unused GPIOs explicitly to zero to avoid floating outputs
    assign GPIO_0[17:0]   = 18'b0;
    assign GPIO_0[19]     = 1'b0;
    assign GPIO_0[26:23]  = 4'b0;
    assign GPIO_0[34:28]  = 8'b0;
	 
	 // =========================================================================
    // === Module Instantiations ===
    // =========================================================================

    // --- Radar Module ---
    radar radar_inst (
        .clk           (CLOCK_50),
        .rst_n         (s1),                // Reset via button
        .echo          (echo_in),
        .trig          (trig_out),
        .pulse_alert   (pulse_alert),
        .distance_cm   (distance_cm),
        .alert_active  (alert_active),
		  .trig_choice	  (trig_choice)
    );

    // --- Servo Driver Module ---
    servo_driver servo_driver_inst (
        .clk           (CLOCK_50),
        .reset_n       (s1),                // Reset via button
        .alert_active  (alert_active),
        .servo_pwm_out (pwm_out),
		  .state 		  (state),
		  .angle 		  (angle),
		  .joy_pos		  (result)
    );
	 
	 // --- Button Toggle Module for MANUAL MODE ---
	 button_toggle button_toggle_inst (
		  .clk           (CLOCK_50),
        .reset_n       (s1),                // Reset via button
        .button  		  (s2),
        .toggled_output(toggled)
	 );
	 
	 // --- UART Transmission ---
	 uart_packet_tx uart_sender (
		  .clk           (CLOCK_50),
        .reset_n       (s1),                // Reset via button
        .distance_cm   (distance_cm),
        .angle 		  (angle),
		  .uart_tx_pin   (uart_tx_pin)
	 );
	 
	 // --- Classic Modules ---
	 decode2 decode2_0 (.digit,.ct) ;
    decode7 decode7_0 (.num(disp_digit),.leds) ;
    encoder encoder_1 (.clk(CLOCK_50), .a(enc1_a), .b(enc1_b), .cw(enc1_cw), .ccw(enc1_ccw));
	 enc2chan enc2chan_0 (.clk(CLOCK_50), .cw(enc1_cw), .ccw(enc1_ccw), .reset_n(s1), .chan(trig_choice)) ;
	 adcinterface adcinterface_0 (.clk(ADC_clk), .chan(0), .result(result), .reset_n(s1), .ADC_CONVST, .ADC_SCK, .ADC_SDI, .ADC_SDO) ;
	 
	 // =========================================================================
    // === FSM Definition ===
    // =========================================================================
    typedef enum logic [1:0] {
        SCAN,
        LOCK,
        WAIT_CLEAR,
		  MANUAL
    } state_t;

    state_t state, next_state;
	 logic [31:0] lock_timer;

	 
    // =========================================================================
    // === State Logic ===
    // =========================================================================

	 // --- State Transition ---
	 always_comb begin
		next_state = state;
		
		if (toggled) begin
			next_state = MANUAL;
		
		end else begin

			case (state)
				SCAN: begin
						if (alert_active)
							next_state = LOCK;
				end

				LOCK: begin
						if (lock_timer == 0)
							next_state = WAIT_CLEAR;
				end

				WAIT_CLEAR: begin
						if (!alert_active)
							next_state = SCAN;
				end
				
				MANUAL: begin
						next_state = SCAN;
				end
			endcase
		end
	 end

	 // --- State Timer (LOCK -> WAIT_CLEAR) ---
	 always_ff @(posedge CLOCK_50 or negedge s1) begin
		if (!s1) begin
			state <= SCAN;
			lock_timer <= 0;
		end else begin
			state <= next_state;

			if (state == LOCK && lock_timer > 0)
					lock_timer <= lock_timer - 1;
			else if (state != LOCK)
					lock_timer <= 100_000_000;  // 2 seconds at 50 MHz
		end
    end
  
	 
    // =========================================================================
    // === LEDs ===
    // =========================================================================
    always_comb begin
		if(state == MANUAL) begin
			{red, blue, green} = 3'b111;     // White light in MANUAL mode
		end else begin	 
			red = (state == LOCK);
			blue = (state == WAIT_CLEAR);
			green = (state == SCAN);
		end
	 end
	 // =========================================================================
    // === Encoder Lookup for Distance Values (disp_digit) ===
    // =========================================================================
	 always_comb begin
        case (trig_choice)
            3'd0: disp_choice = 16'h0010; //10cm
            3'd1: disp_choice = 16'h0025; //25cm
            3'd2: disp_choice = 16'h0050; //50cm
            3'd3: disp_choice = 16'h0075; //75cm
            3'd4: disp_choice = 16'h0100; //100cm
            3'd5: disp_choice = 16'h0150; //150cm
            3'd6: disp_choice = 16'h0200; //200cm
            3'd7: disp_choice = 16'h0250; //250cm
        endcase
    end
	 
	 // =========================================================================
    // === Segment Display Logic ===
    // =========================================================================
	 
	 // use count to divide clock and generate a 2 bit digit counter to determine which digit to display
    always_ff @(posedge CLOCK_50) begin
	   	clk_div_count <= clk_div_count + 1'b1 ;		
	 end
	 
	 
	 // assign the top two bits of count to select digit to display
    assign digit = clk_div_count[15:14]; 
    assign ADC_clk = clk_div_count[4] ;	 
	 
	 
	 always_comb begin
	 //Convert distance_cm into decimal for the display
    hundreds = (distance_cm / 100) % 10;
    tens     = (distance_cm / 10)  % 10;
    ones     =  distance_cm % 10;
	 end
  

   // MANUAL mode shows the distance of the presence as determined by the radar module 
   always_comb begin 
		if (state == MANUAL) begin
			case(digit)				
				2'b00 : disp_digit = ones ; 
				2'b01 : disp_digit = tens ; 
				2'b10 : disp_digit = hundreds ;
				2'b11 : disp_digit = 4'hF ;
				default : disp_digit = 0 ;
			endcase
	// AUTO (not MANUAL) mode displays the current set distance to trigger an alert (controlled by encoder 1)
		end else begin		
			//Depending on the (digit) being selected, load the correct value into the display
			case(digit)
				2'b00 : disp_digit = disp_choice[3:0] ; 
				2'b01 : disp_digit = disp_choice[7:4] ; 
				2'b10 : disp_digit = disp_choice[11:8] ;
				2'b11 : disp_digit = 4'hF ;
				default : disp_digit = 0 ;
			endcase  
		end
   end  
	
endmodule
