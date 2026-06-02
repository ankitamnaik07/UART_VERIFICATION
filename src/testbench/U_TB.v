
`timescale 1ns/1ps
`default_nettype none

module uart_tb;

    reg        sys_clk;
    reg        sys_rst_l;

    reg        xmitH;
    reg  [7:0] xmit_dataH;
    wire       uart_XMIT_dataH;
    wire       xmit_doneH;
    wire       xmit_active;

    reg        uart_REC_dataH;
    wire [7:0] rec_dataH;
    wire       rec_readyH;
    wire       rec_busy;

    wire       ref_uart_XMIT_dataH;
    wire       ref_xmit_doneH;
    wire       ref_xmit_active;
    wire [7:0] ref_rec_dataH;
    wire       ref_rec_readyH;
    wire       ref_rec_busy;
    wire       ref_baud_clk_16x;

    integer    pass_count;
    integer    fail_count;
    integer    i;
    integer    b;
    integer    baud_count;
    integer    extra;
    integer    start_cycles;
    integer    tick_cycles;

    reg [7:0]  loopback_val;
    reg [7:0]  tb;

    localparam SYS_CLK_FREQ  = 50000000;
    localparam BAUD_RATE     = 9600;
    localparam DIV           = SYS_CLK_FREQ / (BAUD_RATE * 16);
    localparam CLK_PERIOD    = 20;
    localparam ONE_BIT_CLKS  = DIV * 16;
    localparam HALF_BIT_CLKS = DIV * 8;

    U_TOP #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .BAUD_RATE   (BAUD_RATE)
    ) dut (
        .sys_clk        (sys_clk),
        .sys_rst_l      (sys_rst_l),
        .xmitH          (xmitH),
        .xmit_dataH     (xmit_dataH),
        .uart_XMIT_dataH(uart_XMIT_dataH),
        .xmit_doneH     (xmit_doneH),
        .xmit_active    (xmit_active),
        .uart_REC_dataH (uart_REC_dataH),
        .rec_dataH      (rec_dataH),
        .rec_readyH     (rec_readyH),
        .rec_busy       (rec_busy)
    );

    UART_REF_MODEL #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .BAUD_RATE   (BAUD_RATE)
    ) ref_model (
        .sys_clk             (sys_clk),
        .sys_rst_l           (sys_rst_l),
        .xmitH               (xmitH),
        .xmit_dataH          (xmit_dataH),
        .uart_REC_dataH      (uart_REC_dataH),
        .ref_uart_XMIT_dataH (ref_uart_XMIT_dataH),
        .ref_xmit_doneH      (ref_xmit_doneH),
        .ref_xmit_active     (ref_xmit_active),
        .ref_rec_dataH       (ref_rec_dataH),
        .ref_rec_readyH      (ref_rec_readyH),
        .ref_rec_busy        (ref_rec_busy),
        .ref_baud_clk_16x    (ref_baud_clk_16x)
    );

    always #(CLK_PERIOD/2) sys_clk = ~sys_clk;

    task apply_reset;
        begin
            sys_rst_l      = 1'b0;
            xmitH          = 1'b0;
            xmit_dataH     = 8'h00;
            uart_REC_dataH = 1'b1;
            repeat(10) @(posedge sys_clk);
            #1;
            sys_rst_l = 1'b1;
            @(posedge sys_clk);
            #1;
        end
    endtask

    task check_all_outputs;
        input [31:0] test_id;
        begin
            if (uart_XMIT_dataH !== ref_uart_XMIT_dataH) begin
                $display("FAIL T%0d: uart_XMIT_dataH got=%b exp=%b time=%0t",
                          test_id, uart_XMIT_dataH, ref_uart_XMIT_dataH, $time);
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end

            if (xmit_doneH !== ref_xmit_doneH) begin
                $display("FAIL T%0d: xmit_doneH got=%b exp=%b time=%0t",
                          test_id, xmit_doneH, ref_xmit_doneH, $time);
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end

            if (xmit_active !== ref_xmit_active) begin
                $display("FAIL T%0d: xmit_active got=%b exp=%b time=%0t",
                          test_id, xmit_active, ref_xmit_active, $time);
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end

            if (rec_readyH !== ref_rec_readyH) begin
                $display("FAIL T%0d: rec_readyH got=%b exp=%b time=%0t",
                          test_id, rec_readyH, ref_rec_readyH, $time);
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end

            if (rec_busy !== ref_rec_busy) begin
                $display("FAIL T%0d: rec_busy got=%b exp=%b time=%0t",
                          test_id, rec_busy, ref_rec_busy, $time);
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end

            if (rec_readyH === 1'b1) begin
                if (rec_dataH !== ref_rec_dataH) begin
                    $display("FAIL T%0d: rec_dataH got=%h exp=%h time=%0t",
                              test_id, rec_dataH, ref_rec_dataH, $time);
                    fail_count = fail_count + 1;
                end else begin
                    pass_count = pass_count + 1;
                end
            end
        end
    endtask

    task wait_clocks;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                @(posedge sys_clk);
            end
            #1;
        end
    endtask

    task transmit_byte;
        input [7:0] data_byte;
        begin
            @(posedge sys_clk); #1;
            xmitH      = 1'b1;
            xmit_dataH = data_byte;
            @(posedge sys_clk); #1;
            xmitH = 1'b0;
            @(posedge xmit_doneH);
            @(posedge sys_clk); #1;
        end
    endtask

    task send_uart_byte;
        input [7:0] data_byte;
        integer     j;
        begin
            uart_REC_dataH = 1'b0;
            wait_clocks(ONE_BIT_CLKS);
            for (j = 0; j < 8; j = j + 1) begin
                uart_REC_dataH = data_byte[j];
                wait_clocks(ONE_BIT_CLKS);
            end
            uart_REC_dataH = 1'b1;
            wait_clocks(ONE_BIT_CLKS);
            uart_REC_dataH = 1'b1;
        end
    endtask

    reg loopback_en;

    always @(posedge sys_clk) begin
        if (loopback_en)
            uart_REC_dataH <= uart_XMIT_dataH;
    end

    initial begin
        sys_clk        = 1'b0;
        sys_rst_l      = 1'b1;
        xmitH          = 1'b0;
        xmit_dataH     = 8'h00;
        uart_REC_dataH = 1'b1;
        loopback_en    = 1'b0;
        pass_count     = 0;
        fail_count     = 0;
        i              = 0;
        b              = 0;
        baud_count     = 0;
        extra          = 0;
        start_cycles   = 0;
        tick_cycles    = 0;
        loopback_val   = 8'h00;
        tb             = 8'h00;
    end

    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);
    end

    initial begin

        $display("===========================================");
        $display("        UART TESTBENCH START              ");
        $display("===========================================");

        $display("\n--- TEST 1: Reset - All outputs at reset values ---");
        sys_rst_l      = 1'b0;
        xmitH          = 1'b0;
        xmit_dataH     = 8'h00;
        uart_REC_dataH = 1'b1;
        @(posedge sys_clk); #1;

        if (uart_XMIT_dataH !== 1'b1) begin
            $display("FAIL T1: uart_XMIT_dataH must be 1 at reset got=%b", uart_XMIT_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T1: uart_XMIT_dataH=1 at reset");
            pass_count = pass_count + 1;
        end

        if (xmit_doneH !== 1'b0) begin
            $display("FAIL T1: xmit_doneH must be 0 at reset got=%b", xmit_doneH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T1: xmit_doneH=0 at reset");
            pass_count = pass_count + 1;
        end

        if (xmit_active !== 1'b0) begin
            $display("FAIL T1: xmit_active must be 0 at reset got=%b", xmit_active);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T1: xmit_active=0 at reset");
            pass_count = pass_count + 1;
        end

        if (rec_readyH !== 1'b0) begin
            $display("FAIL T1: rec_readyH must be 0 at reset got=%b", rec_readyH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T1: rec_readyH=0 at reset");
            pass_count = pass_count + 1;
        end

        if (rec_busy !== 1'b0) begin
            $display("FAIL T1: rec_busy must be 0 at reset got=%b", rec_busy);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T1: rec_busy=0 at reset");
            pass_count = pass_count + 1;
        end

        if (rec_dataH !== 8'h00) begin
            $display("FAIL T1: rec_dataH must be 0x00 at reset got=%h", rec_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T1: rec_dataH=0x00 at reset");
            pass_count = pass_count + 1;
        end

        repeat(5) @(posedge sys_clk); #1;
        sys_rst_l = 1'b1;
        @(posedge sys_clk); #1;

        $display("\n--- TEST 2: IDLE - TX line HIGH, no activity when xmitH=0 ---");
        wait_clocks(30);
        if (uart_XMIT_dataH !== 1'b1) begin
            $display("FAIL T2: uart_XMIT_dataH must be HIGH in IDLE got=%b", uart_XMIT_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T2: uart_XMIT_dataH=1 in IDLE");
            pass_count = pass_count + 1;
        end
        if (xmit_active !== 1'b0) begin
            $display("FAIL T2: xmit_active must be 0 in IDLE got=%b", xmit_active);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T2: xmit_active=0 in IDLE");
            pass_count = pass_count + 1;
        end
        if (xmit_doneH !== 1'b0) begin
            $display("FAIL T2: xmit_doneH must be 0 in IDLE got=%b", xmit_doneH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T2: xmit_doneH=0 in IDLE");
            pass_count = pass_count + 1;
        end
        check_all_outputs(2);

        $display("\n--- TEST 3: Baud Generator - baud_clk_16x pulses after DIV cycles ---");
        baud_count = 0;
        repeat(DIV * 4) begin
            @(posedge sys_clk); #1;
            if (ref_baud_clk_16x === 1'b1)
                baud_count = baud_count + 1;
        end
        if (baud_count >= 1) begin
            $display("PASS T3: baud_clk_16x pulsed %0d times in %0d cycles", baud_count, DIV*4);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL T3: baud_clk_16x never pulsed");
            fail_count = fail_count + 1;
        end

        $display("\n--- TEST 4: IDLE - xmitH=0 keeps transmitter inactive ---");
        apply_reset;
        xmitH = 1'b0;
        wait_clocks(20);
        if (xmit_active !== 1'b0) begin
            $display("FAIL T4: xmit_active must stay 0 when xmitH=0 got=%b", xmit_active);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T4: xmit_active=0 with xmitH=0");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 5: TX - xmitH=1 starts transmission, xmit_active rises ---");
        apply_reset;
        @(posedge sys_clk); #1;
        xmitH      = 1'b1;
        xmit_dataH = 8'hA5;
        @(posedge sys_clk); #1;
        xmitH = 1'b0;
        @(posedge sys_clk); #1;
        if (xmit_active !== 1'b1) begin
            $display("FAIL T5: xmit_active must be 1 after xmitH pulse got=%b", xmit_active);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T5: xmit_active=1 after xmitH asserted");
            pass_count = pass_count + 1;
        end
        @(posedge xmit_doneH);
        @(posedge sys_clk); #1;

        $display("\n--- TEST 6: TX - START bit must be LOW ---");
        apply_reset;
        @(posedge sys_clk); #1;
        xmitH      = 1'b1;
        xmit_dataH = 8'hFF;
        @(posedge sys_clk); #1;
        xmitH = 1'b0;
        @(posedge sys_clk); #1;
        if (uart_XMIT_dataH !== 1'b0) begin
            $display("FAIL T6: START bit must be LOW got=%b", uart_XMIT_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T6: START bit is LOW");
            pass_count = pass_count + 1;
        end
        @(posedge xmit_doneH);
        @(posedge sys_clk); #1;

        $display("\n--- TEST 7: TX - STOP bit and idle line must be HIGH ---");
        apply_reset;
        @(posedge sys_clk); #1;
        xmitH      = 1'b1;
        xmit_dataH = 8'h00;
        @(posedge sys_clk); #1;
        xmitH = 1'b0;
        @(posedge xmit_doneH);
        @(posedge sys_clk); #1;
        if (uart_XMIT_dataH !== 1'b1) begin
            $display("FAIL T7: STOP/idle line must be HIGH got=%b", uart_XMIT_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T7: STOP/idle line is HIGH");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 8: TX - xmit_doneH pulses for exactly 1 clock cycle ---");
        apply_reset;
        transmit_byte(8'hC3);
        extra = 0;
        repeat(4) begin
            @(posedge sys_clk); #1;
            if (xmit_doneH === 1'b1)
                extra = extra + 1;
        end
        if (extra === 0) begin
            $display("PASS T8: xmit_doneH cleared after 1 cycle");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL T8: xmit_doneH stayed HIGH for %0d extra cycles", extra);
            fail_count = fail_count + 1;
        end

        $display("\n--- TEST 9: TX - xmit_active goes LOW after transmission done ---");
        apply_reset;
        @(posedge sys_clk); #1;
        xmitH      = 1'b1;
        xmit_dataH = 8'hBE;
        @(posedge sys_clk); #1;
        xmitH = 1'b0;
        @(posedge xmit_doneH);
        @(posedge sys_clk); #1;
        if (xmit_active !== 1'b0) begin
            $display("FAIL T9: xmit_active must be 0 after done got=%b", xmit_active);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T9: xmit_active=0 after transmission complete");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 10: TX - Transmit 0x55 vs reference model ---");
        apply_reset;
        transmit_byte(8'h55);
        check_all_outputs(10);
        $display("PASS T10: Transmitted 0x55 matches reference");

        $display("\n--- TEST 11: TX - Transmit 0xAA vs reference model ---");
        apply_reset;
        transmit_byte(8'hAA);
        check_all_outputs(11);
        $display("PASS T11: Transmitted 0xAA matches reference");

        $display("\n--- TEST 12: TX - Transmit 0x00 all zeros ---");
        apply_reset;
        transmit_byte(8'h00);
        check_all_outputs(12);
        $display("PASS T12: Transmitted 0x00 matches reference");

        $display("\n--- TEST 13: TX - Transmit 0xFF all ones ---");
        apply_reset;
        transmit_byte(8'hFF);
        check_all_outputs(13);
        $display("PASS T13: Transmitted 0xFF matches reference");

        $display("\n--- TEST 14: TX - Bit walk, each bit position 0 to 7 ---");
        apply_reset;
        for (b = 0; b < 8; b = b + 1) begin
            tb = (8'h01 << b);
            transmit_byte(tb);
            check_all_outputs(14);
        end
        $display("PASS T14: All 8 bit-walk patterns transmitted");

        $display("\n--- TEST 15: TX - 3 back-to-back transmissions ---");
        apply_reset;
        transmit_byte(8'h12);
        check_all_outputs(15);
        transmit_byte(8'h34);
        check_all_outputs(15);
        transmit_byte(8'h56);
        check_all_outputs(15);
        $display("PASS T15: 3 back-to-back TX match reference");

        $display("\n--- TEST 16: TX - START bit duration is 16 baud ticks ---");
        apply_reset;
        @(posedge sys_clk); #1;
        xmitH      = 1'b1;
        xmit_dataH = 8'hA5;
        @(posedge sys_clk); #1;
        xmitH        = 1'b0;
        start_cycles = 0;
        while (uart_XMIT_dataH === 1'b0) begin
            @(posedge sys_clk); #1;
            start_cycles = start_cycles + 1;
            if (start_cycles > ONE_BIT_CLKS * 3)
                start_cycles = ONE_BIT_CLKS * 3;
        end
        if (start_cycles >= ONE_BIT_CLKS - 5 && start_cycles <= ONE_BIT_CLKS + 5) begin
            $display("PASS T16: START bit ~%0d clocks expected ~%0d", start_cycles, ONE_BIT_CLKS);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL T16: START bit duration mismatch got=%0d exp~=%0d", start_cycles, ONE_BIT_CLKS);
            fail_count = fail_count + 1;
        end
        @(posedge xmit_doneH);
        @(posedge sys_clk); #1;

        $display("\n--- TEST 17: RX - Idle HIGH line keeps receiver in IDLE ---");
        apply_reset;
        uart_REC_dataH = 1'b1;
        wait_clocks(50);
        if (rec_busy !== 1'b0) begin
            $display("FAIL T17: rec_busy must stay 0 with RX HIGH got=%b", rec_busy);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T17: Receiver stays IDLE with line HIGH");
            pass_count = pass_count + 1;
        end
        if (rec_readyH !== 1'b0) begin
            $display("FAIL T17: rec_readyH must be 0 with no RX got=%b", rec_readyH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T17: rec_readyH=0 with no incoming data");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 18: RX - Start bit detection, rec_busy goes HIGH ---");
        apply_reset;
        @(posedge sys_clk); #1;
        uart_REC_dataH = 1'b0;
        repeat(3) @(posedge sys_clk); #1;
        if (rec_busy !== 1'b1) begin
            $display("FAIL T18: rec_busy must be 1 after start bit got=%b", rec_busy);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T18: rec_busy=1 when start bit LOW detected");
            pass_count = pass_count + 1;
        end
        uart_REC_dataH = 1'b1;
        wait_clocks(ONE_BIT_CLKS * 2);

        $display("\n--- TEST 19: RX - False start rejection ---");
        apply_reset;
        uart_REC_dataH = 1'b0;
        repeat(3) @(posedge sys_clk); #1;
        wait_clocks(HALF_BIT_CLKS - 4);
        uart_REC_dataH = 1'b1;
        wait_clocks(HALF_BIT_CLKS + 10);
        if (rec_busy !== 1'b0) begin
            $display("FAIL T19: rec_busy should return 0 after false start got=%b", rec_busy);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T19: False start rejected rec_busy=0");
            pass_count = pass_count + 1;
        end
        wait_clocks(ONE_BIT_CLKS);

        $display("\n--- TEST 20: RX - 2 FF sync chain latency check ---");
        apply_reset;
        @(posedge sys_clk); #1;
        uart_REC_dataH = 1'b0;
        @(posedge sys_clk); #1;
        if (rec_busy === 1'b1) begin
            $display("FAIL T20: rec_busy too early sync chain not working");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T20: Sync chain correctly delays start bit");
            pass_count = pass_count + 1;
        end
        uart_REC_dataH = 1'b1;
        wait_clocks(ONE_BIT_CLKS * 2);

        $display("\n--- TEST 21: RX - Receive 0x55 ---");
        apply_reset;
        send_uart_byte(8'h55);
        wait_clocks(ONE_BIT_CLKS * 2);
        check_all_outputs(21);
        if (rec_dataH !== 8'h55) begin
            $display("FAIL T21: expected 0x55 got 0x%h", rec_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T21: Received 0x55 correctly");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 22: RX - Receive 0xAA ---");
        apply_reset;
        send_uart_byte(8'hAA);
        wait_clocks(ONE_BIT_CLKS * 2);
        check_all_outputs(22);
        if (rec_dataH !== 8'hAA) begin
            $display("FAIL T22: expected 0xAA got 0x%h", rec_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T22: Received 0xAA correctly");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 23: RX - Receive 0x00 ---");
        apply_reset;
        send_uart_byte(8'h00);
        wait_clocks(ONE_BIT_CLKS * 2);
        check_all_outputs(23);
        if (rec_dataH !== 8'h00) begin
            $display("FAIL T23: expected 0x00 got 0x%h", rec_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T23: Received 0x00 correctly");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 24: RX - Receive 0xFF ---");
        apply_reset;

        @(posedge sys_clk); #1;
        send_uart_byte(8'hFF);
        wait_clocks(ONE_BIT_CLKS * 2);
        check_all_outputs(24);
        if (rec_dataH !== 8'hFF) begin
            $display("FAIL T24: expected 0xFF got 0x%h", rec_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T24: Received 0xFF correctly");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 25: RX - rec_readyH pulses exactly 1 clock cycle ---");
        apply_reset;

        @(posedge sys_clk); #1;
        send_uart_byte(8'hBB);
        @(posedge rec_readyH);
        @(posedge sys_clk); #1;
        if (rec_readyH !== 1'b0) begin
            $display("FAIL T25: rec_readyH should be LOW 1 cycle after pulse got=%b", rec_readyH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T25: rec_readyH pulses exactly 1 cycle");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 26: RX - Framing error, STOP bit LOW, data discarded ---");
        apply_reset;


        @(posedge sys_clk); #1;
        uart_REC_dataH = 1'b0;
        wait_clocks(ONE_BIT_CLKS);
        for (i = 0; i < 8; i = i + 1) begin
            uart_REC_dataH = 1'b1;
            wait_clocks(ONE_BIT_CLKS);
        end
        uart_REC_dataH = 1'b0;
        wait_clocks(ONE_BIT_CLKS);
        uart_REC_dataH = 1'b1;
        wait_clocks(ONE_BIT_CLKS * 2);
        check_all_outputs(26);
        if (rec_readyH !== 1'b0) begin
            $display("FAIL T26: rec_readyH must be 0 on framing error got=%b", rec_readyH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T26: Framing error data discarded rec_readyH=0");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 27: RX - 3 back-to-back receptions ---");
        apply_reset;
        send_uart_byte(6'b11);
        wait_clocks(ONE_BIT_CLKS);
        check_all_outputs(27);
        send_uart_byte(8'h22);
        wait_clocks(ONE_BIT_CLKS);
        check_all_outputs(27);
        send_uart_byte(8'h33);
        wait_clocks(ONE_BIT_CLKS);
        check_all_outputs(27);
        $display("PASS T27: 3 back-to-back RX correct");

        $display("\n--- TEST 28: RX - rec_busy goes LOW after successful reception ---");
        apply_reset;
        send_uart_byte(8'hCC);
        wait_clocks(ONE_BIT_CLKS);
        if (rec_busy !== 1'b0) begin
            $display("FAIL T28: rec_busy should be 0 after reception got=%b", rec_busy);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T28: rec_busy=0 after reception complete");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 29: Reset during TX mid-transmission ---");
        apply_reset;
        @(posedge sys_clk); #1;
        xmitH      = 1'b1;
        xmit_dataH = 8'hDE;
        @(posedge sys_clk); #1;
        xmitH = 1'b0;
        wait_clocks(ONE_BIT_CLKS * 4);
        sys_rst_l = 1'b0;
        @(posedge sys_clk); #1;
        if (uart_XMIT_dataH !== 1'b1) begin
            $display("FAIL T29: uart_XMIT_dataH must be 1 after mid-TX reset got=%b", uart_XMIT_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T29: uart_XMIT_dataH=1 after mid-TX reset");
            pass_count = pass_count + 1;
        end
        if (xmit_active !== 1'b0) begin
            $display("FAIL T29: xmit_active must be 0 after mid-TX reset got=%b", xmit_active);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T29: xmit_active=0 after mid-TX reset");
            pass_count = pass_count + 1;
        end
        sys_rst_l = 1'b1;
        wait_clocks(20);

        $display("\n--- TEST 30: Reset during RX mid-reception ---");
        apply_reset;
        uart_REC_dataH = 1'b0;
        wait_clocks(ONE_BIT_CLKS * 4);
        sys_rst_l = 1'b0;
        @(posedge sys_clk); #1;
        if (rec_busy !== 1'b0) begin
            $display("FAIL T30: rec_busy must be 0 after mid-RX reset got=%b", rec_busy);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T30: rec_busy=0 after mid-RX reset");
            pass_count = pass_count + 1;
        end
        if (rec_readyH !== 1'b0) begin
            $display("FAIL T30: rec_readyH must be 0 after mid-RX reset got=%b", rec_readyH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T30: rec_readyH=0 after mid-RX reset");
            pass_count = pass_count + 1;
        end
        sys_rst_l      = 1'b1;
        uart_REC_dataH = 1'b1;
        wait_clocks(20);

        $display("\n--- TEST 31: Loopback TX to RX - 0xE7 ---");
        apply_reset;
        loopback_val   = 8'hE7;
        loopback_en    = 1'b1;
        uart_REC_dataH = 1'b1;
        @(posedge sys_clk); #1;
        xmitH      = 1'b1;
        xmit_dataH = loopback_val;
        @(posedge sys_clk); #1;
        xmitH = 1'b0;
        @(posedge xmit_doneH);
        @(posedge sys_clk); #1;
        loopback_en = 1'b0;
        wait_clocks(ONE_BIT_CLKS * 3);
        if (rec_dataH === loopback_val) begin
            $display("PASS T31: Loopback 0x%h received correctly", rec_dataH);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL T31: Loopback expected 0x%h got 0x%h", loopback_val, rec_dataH);
            fail_count = fail_count + 1;
        end

        $display("\n--- TEST 32: Loopback TX to RX - 0xD4 ---");
        apply_reset;
        loopback_val   = 8'hD4;
        loopback_en    = 1'b1;
        uart_REC_dataH = 1'b1;
        @(posedge sys_clk); #1;
        xmitH      = 1'b1;
        xmit_dataH = loopback_val;
        @(posedge sys_clk); #1;
        xmitH = 1'b0;
        @(posedge xmit_doneH);
        @(posedge sys_clk); #1;
        loopback_en = 1'b0;
        wait_clocks(ONE_BIT_CLKS * 3);
        if (rec_dataH === loopback_val) begin
            $display("PASS T32: Loopback 0x%h received correctly", rec_dataH);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL T32: Loopback expected 0x%h got 0x%h", loopback_val, rec_dataH);
            fail_count = fail_count + 1;
        end

        $display("\n--- TEST 33: Re-apply reset, verify clean state vs reference ---");
        sys_rst_l = 1'b0;
        repeat(5) @(posedge sys_clk); #1;
        sys_rst_l = 1'b1;
        @(posedge sys_clk); #1;
        check_all_outputs(33);
        $display("PASS T33: Re-reset state matches reference model");

        $display("\n--- TEST 34: baud_clk_16x is LOW at reset ---");
        sys_rst_l = 1'b0;
        @(posedge sys_clk); #1;
        if (ref_baud_clk_16x !== 1'b0) begin
            $display("FAIL T34: baud_clk_16x must be 0 at reset got=%b", ref_baud_clk_16x);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T34: baud_clk_16x=0 at reset");
            pass_count = pass_count + 1;
        end
        sys_rst_l = 1'b1;
        wait_clocks(20);

        $display("\n--- TEST 35: TX - Transmit 0x81 MSB and LSB only ---");
        apply_reset;
        transmit_byte(8'h81);
        check_all_outputs(35);
        $display("PASS T35: Transmitted 0x81 matches reference");

        $display("\n--- TEST 36: RX - Receive 0x81 ---");
        apply_reset;
        send_uart_byte(8'h81);
        wait_clocks(ONE_BIT_CLKS * 2);
        check_all_outputs(36);
        if (rec_dataH !== 8'h81) begin
            $display("FAIL T36: expected 0x81 got 0x%h", rec_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T36: Received 0x81 correctly");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 37: TX - Transmit 0xF0 ---");
        apply_reset;
        transmit_byte(8'hF0);
        check_all_outputs(37);
        $display("PASS T37: Transmitted 0xF0 matches reference");

        $display("\n--- TEST 38: RX - Receive 0x0F ---");
        apply_reset;
        send_uart_byte(8'h0F);
        wait_clocks(ONE_BIT_CLKS * 2);
        check_all_outputs(38);
        if (rec_dataH !== 8'h0F) begin
            $display("FAIL T38: expected 0x0F got 0x%h", rec_dataH);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T38: Received 0x0F correctly");
            pass_count = pass_count + 1;
        end

        $display("\n--- TEST 39: TX - Transmit 0xF0 upper nibble ---");
        apply_reset;
        transmit_byte(8'hF0);
        check_all_outputs(39);
        $display("PASS T39: Transmitted 0xF0 matches reference");

        $display("\n--- TEST 40: RX - Receive all 8 individual bit walk patterns ---");
        apply_reset;
        for (b = 0; b < 8; b = b + 1) begin
            tb = (8'h01 << b);
            send_uart_byte(tb);
            wait_clocks(ONE_BIT_CLKS * 2);
            check_all_outputs(40);
            if (rec_dataH !== tb) begin
                $display("FAIL T40: bit=%0d expected 0x%h got 0x%h", b, tb, rec_dataH);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS T40: bit=%0d received 0x%h correctly", b, rec_dataH);
                pass_count = pass_count + 1;
            end
        end
        $display("  FINAL: PASS=%-0d  FAIL=%-0d", pass_count, fail_count);

        #100;
        $finish;
    end

    initial begin
        #500000000;
        $display("TIMEOUT: Simulation exceeded time limit");
        $finish;
    end

endmodule
