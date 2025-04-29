// ============================================================================
// Module: uart_packet_tx
// Description: Format angle and distance data to send using uart_tx, sends a packet to the Tx module every (1) second
// Author: Yizuo Chen && Ryan McKay
// ============================================================================

module uart_packet_tx (
    input  logic clk,
    input  logic reset_n,

    input  logic [7:0]  angle,          // Range: 0–180
    input  logic [15:0] distance_cm,    // Range: 0–999

    output logic uart_tx_pin				 // GPIO_0[35]
);

    // UART transmitter interface
    logic [7:0] uart_data;
    logic       uart_go, uart_busy;

	 // --- UART Transmission Send Module ---
    uart_tx #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(115200)
    ) tx_inst (
        .clk(clk),
        .reset_n(reset_n),
        .data_in(uart_data),
        .transmit(uart_go),
        .tx(uart_tx_pin),
        .busy(uart_busy)
    );

    // ------------------------------------------------------------------------
    // === Digit Extraction (Convert binary → ASCII characters) ===============
    // ------------------------------------------------------------------------

	 // Convert the values of angle and distance to decimal for transmission
    logic [7:0] a100, a10, a1;
    logic [7:0] d100, d10, d1;

	 // Using "0" changes the value type to ASCII
    assign a100 = "0" + ((angle / 100) % 10);
    assign a10  = "0" + ((angle / 10)  % 10);
    assign a1   = "0" + (angle % 10);

    assign d100 = "0" + ((distance_cm / 100) % 10);
    assign d10  = "0" + ((distance_cm / 10)  % 10);
    assign d1   = "0" + (distance_cm % 10);

    // ------------------------------------------------------------------------
    // === Message Buffer: A123,D045\n ========================================
    // ------------------------------------------------------------------------

    logic [7:0] msg [0:9];

    always_comb begin
        msg[0] = "A";
        msg[1] = a100;
        msg[2] = a10;
        msg[3] = a1;
        msg[4] = ",";
        msg[5] = "D";
        msg[6] = d100;
        msg[7] = d10;
        msg[8] = d1;
        msg[9] = "\n";
    end

    // ------------------------------------------------------------------------
    // === Transmission Logic =================================================
    // ------------------------------------------------------------------------

    logic [3:0] index = 0;
    logic [23:0] wait_counter = 0;
    logic send_trigger = 0;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            uart_go <= 0;
            uart_data <= 8'd0;
            index <= 0;
            wait_counter <= 0;
            send_trigger <= 0;
        end else begin
            // Transmission logic
            if (!uart_busy && !uart_go) begin
                if (send_trigger) begin
                    uart_data <= msg[index];
                    uart_go <= 1;
                    index <= index + 1;
                    if (index == 9) begin
                        index <= 0;
                        send_trigger <= 0; // done sending
                    end
                end
            end else if (uart_go && uart_busy) begin
                uart_go <= 0; // drop transmit pulse once accepted
            end

            // Trigger new transmission every 1 second
            if (!send_trigger && !uart_go && !uart_busy) begin
                if (wait_counter < 24'd50_000_000)
                    wait_counter <= wait_counter + 1;
                else begin
                    wait_counter <= 0;
                    send_trigger <= 1;
                end
            end
        end
    end

endmodule
