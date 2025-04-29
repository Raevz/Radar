// ============================================================================
// Module: servo_driver
// Description: Sweeps a servo motor continuously unless an alert is active
// Authors: Yizuo Chen && Ryan McKay
// ============================================================================
module servo_driver (
    // === Clock and Reset ===
    input  logic clk,             // 50 MHz clock
    input  logic reset_n,         // Active-low reset

    // === Control Signal ===
    input  logic alert_active,    // Stops motion when high

    // === Output ===
    output logic servo_pwm_out,   // PWM signal for servo motor
	 
	 // === State Control ===
	 input logic [1:0] state,		 // Control the servo behaviour
	 
	 // === Joy-X Position for MANUAL Control ===
	 input logic [11:0] joy_pos,
	 
	 // === Servo Angle ===
	 output logic [7:0]  angle     // Current sweep angle (0–180°)
);

    // =========================================================================
    // === Parameters ===
    // =========================================================================
    localparam int CLK_FREQ     = 50_000_000;       // Clock frequency (Hz)
    localparam int PWM_FREQ     = 50;               // Servo update frequency (Hz)
    localparam int PWM_PERIOD   = CLK_FREQ / PWM_FREQ;  // ~20 ms (1,000,000 ticks)

    localparam int PULSE_MIN    = 10_000;           // Min pulse width (~0.5 ms)
    localparam int PULSE_MAX    = 115_000;          // Max pulse width (~2.3 ms)

    localparam int ANGLE_MIN    = 0;
    localparam int ANGLE_MAX    = 180;

    localparam int STEP_DELAY   = 2_200_000;        // Delay between servo steps	 
	 localparam int JOY_STEP = 8; 						 //Minimum amount joy must move to change angle

	 localparam logic [1:0] SCAN = 2'd0, LOCK = 2'd1, WAIT_CLEAR = 2'd2, MANUAL = 2'd3; // Define states from top level module
    // =========================================================================
    // === Internal Registers ===
    // =========================================================================
    logic [19:0] pwm_counter;    // Counts from 0 to PWM_PERIOD
    logic [17:0] pulse_width;    // High-time pulse width in ticks
    logic [22:0] step_counter;   // Controls sweep rate
    logic        direction;      // 0 = increasing angle, 1 = decreasing    
	 
	 logic [11:0] joy_pos_clamped;// Keeps the joystick values in its natural range for scaling
    // =========================================================================
    // === PWM Signal Generation ===
    // =========================================================================
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pwm_counter   <= 0;
            servo_pwm_out <= 0;
        end else begin
            if (pwm_counter < PWM_PERIOD - 1)
                pwm_counter <= pwm_counter + 1;
            else
                pwm_counter <= 0;

            // Generate PWM signal based on current angle's pulse width
            servo_pwm_out <= (pwm_counter < pulse_width);
        end
    end

    // =========================================================================
    // === Angle Sweeping Logic ===
    // =========================================================================
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            step_counter <= 0;
            angle        <= ANGLE_MIN;
            direction    <= 0;
         end else begin
        case (state)
            MANUAL: begin
                angle <= (joy_pos_clamped * ANGLE_MAX) / 3248; //3248 = joyX_max - joyX_min
            end

            SCAN, WAIT_CLEAR: begin
                if (step_counter < STEP_DELAY) begin
                    step_counter <= step_counter + 1;
                end else begin
                    step_counter <= 0;

                    if (!direction) begin
                        if (angle < ANGLE_MAX - 10)
                            angle <= angle + 1;
                        else
                            direction <= 1;
                    end else begin
                        if (angle > ANGLE_MIN + 10)
                            angle <= angle - 1;
                        else
                            direction <= 0;
                    end
                end
            end

            default: ; // LOCK or other states do nothing to angle
        endcase
    end
    end

    // =========================================================================
    // === Angle-to-Pulse Width Mapping ===
    // =========================================================================
    always_comb begin
        // Linear mapping from angle to pulse width
        pulse_width = PULSE_MIN + ((angle * (PULSE_MAX - PULSE_MIN)) / 180);
    end
	 
	 // =========================================================================
    // === Joystick Input Mapping (MANUAL mode) ===
    // =========================================================================
    assign joy_pos_clamped = (joy_pos < 12'd80)   ? 12'd80 :   //'d80 and 'd3328 are the min and max values for the joystick X we are using
                             (joy_pos > 12'd3328) ? 12'd3328 :
                                                  joy_pos;

endmodule
