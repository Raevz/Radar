// ============================================================================
// Module: uart_tx
// Description: Standard UART Tx Module
// Author: ChatGPT, probably stolen from somebody else.
// Comment: Since this module is a boilerplate transmit module, very little input was required from us.
//				Why mess with something that works?
// ============================================================================

module uart_tx #(
    parameter CLK_FREQ = 50_000_000,       // 50 MHz
    parameter BAUD_RATE = 115200
)(
    input  logic clk,
    input  logic reset_n,

    input  logic [7:0] data_in,            // Byte to transmit
    input  logic       transmit,           // Pulse high for 1 clk to start sending
    output logic       tx,                 // UART TX line (to PC)
    output logic       busy                // High when sending
);

    // =========================================================================
    // Internal Constants
    // =========================================================================
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam int BIT_CTR_WIDTH = $clog2(CLKS_PER_BIT);

    // =========================================================================
    // State machine states
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE, START_BIT, DATA_BITS, STOP_BIT, CLEANUP
    } state_t;

    state_t state, next_state;

    logic [BIT_CTR_WIDTH-1:0] clk_counter;
    logic [2:0] bit_index;
    logic [7:0] tx_data;

    // =========================================================================
    // FSM Sequencing
    // =========================================================================
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state       <= IDLE;
            clk_counter <= 0;
            bit_index   <= 0;
            tx          <= 1; // idle is high
            busy        <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1;
                    busy <= 0;
                    if (transmit) begin
                        state    <= START_BIT;
                        tx_data  <= data_in;
                        busy     <= 1;
                        clk_counter <= 0;
                    end
                end

                START_BIT: begin
                    tx <= 0;
                    if (clk_counter < CLKS_PER_BIT - 1)
                        clk_counter <= clk_counter + 1;
                    else begin
                        clk_counter <= 0;
                        state <= DATA_BITS;
                        bit_index <= 0;
                    end
                end

                DATA_BITS: begin
                    tx <= tx_data[bit_index];
                    if (clk_counter < CLKS_PER_BIT - 1)
                        clk_counter <= clk_counter + 1;
                    else begin
                        clk_counter <= 0;
                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else
                            state <= STOP_BIT;
                    end
                end

                STOP_BIT: begin
                    tx <= 1;
                    if (clk_counter < CLKS_PER_BIT - 1)
                        clk_counter <= clk_counter + 1;
                    else begin
                        clk_counter <= 0;
                        state <= CLEANUP;
                    end
                end

                CLEANUP: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
