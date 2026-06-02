module UART_REF_MODEL #(
    parameter integer SYS_CLK_FREQ = 50000000,
    parameter integer BAUD_RATE    = 9600
)(
    input  wire       sys_clk,
    input  wire       sys_rst_l,

    input  wire       xmitH,
    input  wire [7:0] xmit_dataH,

    input  wire       uart_REC_dataH,

    output reg        ref_uart_XMIT_dataH,
    output reg        ref_xmit_doneH,
    output reg        ref_xmit_active,

    output reg  [7:0] ref_rec_dataH,
    output reg        ref_rec_readyH,
    output reg        ref_rec_busy,

    output reg        ref_baud_clk_16x
);

    localparam integer DIV = SYS_CLK_FREQ / (BAUD_RATE * 16);

    integer baud_counter;

    always @(posedge sys_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            baud_counter     <= 0;
            ref_baud_clk_16x <= 1'b0;
        end
        else begin
            if (baud_counter == DIV - 1) begin
                baud_counter     <= 0;
                ref_baud_clk_16x <= 1'b1;
            end
            else begin
                baud_counter     <= baud_counter + 1;
                ref_baud_clk_16x <= 1'b0;
            end
        end
    end

    localparam TX_IDLE  = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_DATA  = 2'd2;
    localparam TX_STOP  = 2'd3;

    reg [1:0] tx_state;
    reg [3:0] tx_tick;
    reg [2:0] tx_bit;
    reg [7:0] tx_shift;

    always @(posedge sys_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            tx_state             <= TX_IDLE;
            ref_uart_XMIT_dataH  <= 1'b1;
            ref_xmit_doneH       <= 1'b0;
            ref_xmit_active      <= 1'b0;
            tx_tick              <= 0;
            tx_bit               <= 0;
            tx_shift             <= 0;
        end
        else begin
            ref_xmit_doneH <= 1'b0;

            case (tx_state)

                TX_IDLE: begin
                    ref_uart_XMIT_dataH <= 1'b1;
                    ref_xmit_active     <= 1'b0;
                    tx_tick             <= 0;
                    tx_bit              <= 0;
                    if (xmitH) begin
                        tx_shift        <= xmit_dataH;
                        tx_state        <= TX_START;
                        ref_xmit_active <= 1'b1;
                    end
                end

                TX_START: begin
                    ref_uart_XMIT_dataH <= 1'b0;
                    if (ref_baud_clk_16x) begin
                        if (tx_tick == 15) begin
                            tx_tick  <= 0;
                            tx_state <= TX_DATA;
                        end
                        else begin
                            tx_tick <= tx_tick + 1;
                        end
                    end
                end

                TX_DATA: begin
                    ref_uart_XMIT_dataH <= tx_shift[tx_bit];
                    if (ref_baud_clk_16x) begin
                        if (tx_tick == 15) begin
                            tx_tick <= 0;
                            if (tx_bit == 7) begin
                                tx_bit   <= 0;
                                tx_state <= TX_STOP;
                            end
                            else begin
                                tx_bit <= tx_bit + 1;
                            end
                        end
                        else begin
                            tx_tick <= tx_tick + 1;
                        end
                    end
                end

                TX_STOP: begin
                    ref_uart_XMIT_dataH <= 1'b1;
                    if (ref_baud_clk_16x) begin
                        if (tx_tick == 15) begin
                            tx_tick         <= 0;
                            tx_state        <= TX_IDLE;
                            ref_xmit_active <= 1'b0;
                            ref_xmit_doneH  <= 1'b1;
                        end
                        else begin
                            tx_tick <= tx_tick + 1;
                        end
                    end
                end

                default: tx_state <= TX_IDLE;

            endcase
        end
    end

    reg rx_sync1, rx_sync2;

    always @(posedge sys_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end
        else begin
            rx_sync1 <= uart_REC_dataH;
            rx_sync2 <= rx_sync1;
        end
    end

    wire rx_clean = rx_sync2;

    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg [1:0] rx_state;
    reg [3:0] rx_tick;
    reg [2:0] rx_bit;
    reg [7:0] rx_shift;

    always @(posedge sys_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            rx_state       <= RX_IDLE;
            ref_rec_dataH  <= 8'd0;
            ref_rec_readyH <= 1'b0;
            ref_rec_busy   <= 1'b0;
            rx_tick        <= 0;
            rx_bit         <= 0;
            rx_shift       <= 0;
        end
        else begin
            ref_rec_readyH <= 1'b0;

            case (rx_state)

                RX_IDLE: begin
                    ref_rec_busy <= 1'b0;
                    rx_tick      <= 0;
                    rx_bit       <= 0;
                    if (rx_clean == 1'b0) begin
                        rx_state     <= RX_START;
                        ref_rec_busy <= 1'b1;
                    end
                end

                RX_START: begin
                    if (ref_baud_clk_16x) begin
                        if (rx_tick == 7) begin
                            rx_tick <= 0;
                            if (rx_clean == 1'b0)
                                rx_state <= RX_DATA;
                            else
                                rx_state <= RX_IDLE;
                        end
                        else begin
                            rx_tick <= rx_tick + 1;
                        end
                    end
                end

                RX_DATA: begin
                    if (ref_baud_clk_16x) begin
                        if (rx_tick == 15) begin
                            rx_tick             <= 0;
                            rx_shift[rx_bit]    <= rx_clean;
                            if (rx_bit == 7) begin
                                rx_bit   <= 0;
                                rx_state <= RX_STOP;
                            end
                            else begin
                                rx_bit <= rx_bit + 1;
                            end
                        end
                        else begin
                            rx_tick <= rx_tick + 1;
                        end
                    end
                end

                RX_STOP: begin
                    if (ref_baud_clk_16x) begin
                        if (rx_tick == 15) begin
                            rx_tick      <= 0;
                            rx_state     <= RX_IDLE;
                            ref_rec_busy <= 1'b0;
                            if (rx_clean == 1'b1) begin
                                ref_rec_dataH  <= rx_shift;
                                ref_rec_readyH <= 1'b1;
                            end
                        end
                        else begin
                            rx_tick <= rx_tick + 1;
                        end
                    end
                end

                default: rx_state <= RX_IDLE;

            endcase
        end
    end

endmodule

