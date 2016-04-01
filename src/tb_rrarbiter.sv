//----------------------------
// Testbench for the Arbiter -
//----------------------------

// This testbench applies valid signals from the requesters,
// deasserts the respective lines as they are ready'd,
// and tests that each valid is ready'd exactly once.

`include "rrarbiter.sv"

`define CLOCKP 10 // clock period
`define CLOCKPDIV2 5 // clock period divided by 2

`define TB_PATTERNS "tb_patterns.txt"// file containing the valid vectors
`define TB_PATTERNS_NUM 8 // number of tests to be run

module tb_rrarbiter;

    parameter D = 32 ; // data width of the arbiter
    parameter N = 128; // number of requesters

    // --
    integer exception_count_i; // holds the count of exceptions
    integer o_ready_count_i  ;

    integer         ready_i                          ;
    logic   [N-1:0] tb_patterns[`TB_PATTERNS_NUM-1:0];


    // signals for the DUT
    logic         clock         ;
    logic         reset         ;
    logic [N-1:0] i_valid       ;
    logic [N-1:0] o_ready       ;
    logic [N-1:0] i_data [D-1:0];
    logic         o_valid       ;
    logic         i_ready       ;
    logic [D-1:0] o_data        ;

    rrarbiter #(N,D) DUT (
        .i_clk  (clock  ),
        .i_rst_n(reset  ),
        .i_valid(i_valid),
        .o_ready(o_ready),
        .i_data (i_data ),
        .o_valid(o_valid),
        .i_ready(i_ready),
        .o_data (o_data )
    );

    // generate a clock
    always begin
        #`CLOCKPDIV2 clock = ~clock;
    end

    integer test_i ;
    integer test_j ;
    integer valid_i;

    integer valid_count_i[`TB_PATTERNS_NUM-1:0];
    integer valids_i     [`TB_PATTERNS_NUM-1:0];

    // test sequence
    initial begin

        $readmemh(`TB_PATTERNS, tb_patterns);

        // calculate total requests that must be honored
        for(test_i = 0; test_i < `TB_PATTERNS_NUM; test_i = test_i + 1) begin
            valid_count_i[test_i] = 0;
            for(valid_i = 0; valid_i < N; valid_i = valid_i + 1) begin
                if(tb_patterns[test_i][valid_i]) begin
                    valid_count_i[test_i] = valid_count_i[test_i] + 1;
                    valids_i[valid_i] = valids_i[valid_i] + 1;
                end
            end
        end

        // fill the requester's data lines with its number
        // ie. requester number five supplies data as 8'b00000004
        for(test_i = 0; test_i < N; test_i = test_i + 1) begin
            for(test_j = 0; test_j < N; test_j = test_j + 1) begin
                i_data[test_j][test_i] = test_i[test_j];
            end
        end

        // initialize all variables
        exception_count_i = 0;
        clock = 0; reset = 0; i_valid = 0; i_ready = 0;

        // wait for first negative edge before de-asserting reset
        @(negedge clock) reset = 1;

        // apply pattern and turn off the granted request after three clock cycles
        for(test_i = 0; test_i < `TB_PATTERNS_NUM; test_i = test_i + 1) begin

            // apply the pattern
            i_valid = tb_patterns[test_i];

            // loop through requesters, de-asserting granted valids
            for(valid_i = 0; valid_i < valid_count_i[test_i]; valid_i = valid_i + 1) begin
                // wait three clock periods and then de-assert the valid, releasing the slot
                #(3*`CLOCKP);
                i_valid = i_valid & ~o_ready;
            end
        end

        // apply pattern and turn off the granted request after three clock periods
        // but only for the next three clock cycles
        for(test_i = 0; test_i < `TB_PATTERNS_NUM; test_i = test_i + 1) begin

            // apply the pattern
            i_valid = tb_patterns[test_i];

            // loop through requesters, de-asserting granted valids
            for(valid_i = 0; valid_i < valid_count_i[test_i]; valid_i = valid_i + 1) begin
                // wait three clock periods and then de-assert the valid, releasing the slot
                #(3*`CLOCKP);
                i_valid = tb_patterns[test_i] & ~o_ready;
            end
            #`CLOCKP;
        end

        $display("Testbench finished. %d exceptions.", exception_count_i);

        if(0 == exception_count_i) begin
            $display("DUT PASSED");
        end else begin
            $display("DUT FAILED");
        end
        $finish;
    end

    // assert an i_ready to the arbiter one clock period after it requests from the next stage
    always @(o_valid) begin : i_ready_logic
        #(1*`CLOCKP);
        i_ready = o_valid;
    end

    // monitoring block
    always @(o_ready) begin

        o_ready_count_i = 0;

        // monitor if a ready is asserted only from those that requested it
        for(ready_i = 0; ready_i < N; ready_i = ready_i + 1) begin
            if(o_ready[ready_i]) begin
                o_ready_count_i = o_ready_count_i + 1;
                if(!i_valid[ready_i]) begin
                    exception_count_i = exception_count_i + 1;
                    $display("EXCEPTION @%e: o_ready granted a line %d without an i_valid.", $realtime, o_ready);
                end
            end
        end

        // monitor if output from arbiter is one-hot encoded
        if(o_ready_count_i > 1) begin
            exception_count_i = exception_count_i + 1;
            $display("EXCEPTION @%e: o_ready (%h) asserted multiple lines.", $realtime, o_ready);
        end
    end

    // massive dump for quick visual check
    always @(negedge clock) begin
        if(1 == reset) begin
            $display("%h %h %h", i_valid, o_ready, o_data);
        end
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end

endmodule
