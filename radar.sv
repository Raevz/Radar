// ============================================================================
// Module: radar
// Description: Ultrasonic-style Doppler radar pulse trigger & echo detector
// Authors: Yizuo Chen && Ryan McKay
// ============================================================================
module radar (
    // === Clock & Reset ===
    input  logic clk,               // 50 MHz clock
    input  logic rst_n,             // Active-low reset

    // === Sensor Interface ===
    input  logic echo,              // Input from sensor echo pin
    output logic trig,              // Output trigger pulse to sensor

    // === System Outputs ===
    output logic pulse_alert,       // High if pulse count exceeds threshold
    output logic [15:0] distance_cm,// Echo pulse-based distance measurement
    output logic alert_active,      // Holds high for timeout period
	 
	 // === System Inputs ===
	 input logic [2:0] trig_choice
);

    // =========================================================================
    // === Parameters ===
    // =========================================================================
    localparam int CLK_FREQ     = 50_000_000;     // 50 MHz system clock
    localparam int TRIG_PERIOD  = 100_000;        // 100 us total trigger cycle
    localparam int TRIG_PULSE   = 500;            // 10 us pulse
    localparam int ALERT_DURATION = 25_000_000;   // 0.5 seconds

    // =========================================================================
    // === Internal Signals ===
    // =========================================================================
    logic [15:0] trig_counter;
    logic        trig_state;

    logic [5:0]  pulse_count;
    logic        echo_d, echo_rising, echo_falling;
    logic [21:0] interval_counter;

    logic [24:0] alert_timer;

    logic [23:0] echo_timer, trig_time;
    logic        measuring_echo;
    logic [15:0] raw_distance_cm;	 


    // =========================================================================
    // === Trigger Pulse Generator (TRIG) ===
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trig_counter <= 0;
            trig_state   <= 0;	
        end else begin
            if (trig_counter < TRIG_PERIOD - 1)
                trig_counter <= trig_counter + 1;
            else
                trig_counter <= 0;

            trig_state <= (trig_counter < TRIG_PULSE); // Pulse high first 10 us
        end
    end

    assign trig = trig_state;

	 
    // =========================================================================
    // === Alert Active Timer (0.5 seconds after trigger) ===
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alert_timer   <= 0;
            alert_active  <= 0;
        end else begin
            if (pulse_alert) begin
                alert_timer  <= ALERT_DURATION - 1;
                alert_active <= 1;
            end else if (alert_timer > 0) begin
                alert_timer  <= alert_timer - 1;
                alert_active <= 1;
            end else begin
                alert_active <= 0;
            end
        end
    end
	 // =========================================================================
    // === Echo Duration Tracking and Threshold Trigger ===
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            echo_timer     <= 0;
            measuring_echo <= 0;
            pulse_alert    <= 0;
            echo_d         <= 0;
            echo_rising    <= 0;
            echo_falling   <= 0;
        end else begin
            echo_d       <= echo;
            echo_rising  <= echo && !echo_d;
            echo_falling <= !echo && echo_d;
				
				// Detect rising edge of signal and measure time until falling edge
            if (echo_rising) begin
                measuring_echo <= 1;
                echo_timer     <= 0;
            end else if (measuring_echo) begin
                if (echo) begin
                    echo_timer <= echo_timer + 1;
                end else begin
                    measuring_echo <= 0;
                    pulse_alert <= (echo_timer < trig_time);
                end
            end
        end
    end
	 
	 
	 // =========================================================================
    // === Distance Conversion for Display/Logging ===
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            raw_distance_cm <= 0;
        else if (echo_falling)
            raw_distance_cm <= echo_timer / 2900;
    end

    assign distance_cm = raw_distance_cm;

	 
	 // =========================================================================
    // === Encoder Lookup for Distance Thresholds ===
    // =========================================================================
	 // Distance is 2900 * (distance in cm) - 2900 is speed of sound divided by period of clock
    always_comb begin
        case (trig_choice)
            3'd0: trig_time = 2900 * 10;
            3'd1: trig_time = 2900 * 25;
            3'd2: trig_time = 2900 * 50;
            3'd3: trig_time = 2900 * 75;
            3'd4: trig_time = 2900 * 100;
            3'd5: trig_time = 2900 * 150;
            3'd6: trig_time = 2900 * 200;
            3'd7: trig_time = 2900 * 250;
        endcase
    end    
endmodule
