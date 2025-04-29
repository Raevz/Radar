// ============================================================================
// Module: button_toggle
// Description: Receive and debounce button input, then toggle output 
// Authors: ChatGPT, pure laziness lead to not programming this one ourselves
// ============================================================================

module button_toggle (
    input  logic clk,
    input  logic reset_n,
    input  logic button,         // active-low physical button
    output logic toggled_output  // flips on each press
);

    logic button_d, button_pressed;

	 // --- Falling Edge Dectection ---
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            button_d <= 1;
            button_pressed <= 0;
        end else begin
            button_d <= button;
            button_pressed <= (~button && button_d);
        end
    end
	
	 // --- Output Toggling ---
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            toggled_output <= 0;
        else if (button_pressed)
            toggled_output <= ~toggled_output;
    end

endmodule
