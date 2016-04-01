/* verilator lint_off UNUSED */
/* verilator lint_off UNOPTFLAT */

//-----------------------
//- Round Robin Arbiter -
//-----------------------

`timescale 1ns/1ps

`include "arbitration_algorithm.sv"

module rrarbiter #(
    N_REQ = 8 , // number of requesters
    DATAW = 64  // width of the data bus
) (
    input  logic             i_clk             , // clock
    input  logic             i_rst_n           , // synchronous reset active low
    // requester signals
    input  logic [N_REQ-1:0] i_valid           , // valids/requests from the requesters
    output logic [N_REQ-1:0] o_ready           , // readys/grants to the requesters
    input  logic [N_REQ-1:0] i_data [DATAW-1:0], // data from requesters
    // next stage signals
    output logic             o_valid           , // valid/request to the next stage
    input  logic             i_ready           , // ready/grant from the next stage
    output logic [DATAW-1:0] o_data              // winning data output to the next stage
);

    logic [N_REQ-1:0] last_ready;
    logic [N_REQ-1:0] next_ready;

    arbitration_algorithm #(N_REQ,DATAW) ar_ag_inst (
        .next_ready   (next_ready),
        .input_valid  (i_valid   ),
        .last_ready   (last_ready),
        .current_ready(o_ready   )
    );

    // request from next stage if one of the requesters has asserted a valid
    assign o_valid = | i_valid;

    // select the data to be sent out
    logic [DATAW-1:0] data_mux;

    genvar i;
    generate
        for (i = 0; i < DATAW; i++) begin
            assign data_mux[i] = |(i_data[i] & o_ready);
        end
    endgenerate

    assign o_data = data_mux;

    // if current requester has de-asserted, move on to next one
    logic should_service_next;
    assign should_service_next = i_ready & (~|(o_ready & i_valid));

    // save the last grant so that it may be used by the arbitration algorithm
    always_ff @(posedge i_clk) begin : proc_last_ready
        if(~i_rst_n) begin
            last_ready <= 0;
        end else if(should_service_next) begin
            last_ready <= o_ready;
        end
    end

    // send out the next ready if a new one should be made available
    always_ff @(posedge i_clk) begin : proc_o_ready
        if(!i_rst_n) begin
            o_ready <= 0;
        end else if(should_service_next) begin
            o_ready <= next_ready;
        end
    end

endmodule
