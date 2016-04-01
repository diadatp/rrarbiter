//-------------------------------------
//- Round Robin Arbitration Algorithm -
//-------------------------------------

`timescale 1ns/1ps

module arbitration_algorithm #(
    N_REQ = 8 , // number of requesters
    DATAW = 64  // width of the data bus
) (
    output [N_REQ-1:0] next_ready ,
    input  [N_REQ-1:0] input_valid, last_ready, current_ready
);

    // generate a mask for priorities strictly greater than the current ready
    logic [N_REQ-1:0] mask_higher_pri_valids;
    assign mask_higher_pri_valids[0]         = 1'b0;
    assign mask_higher_pri_valids[N_REQ-1:1] = mask_higher_pri_valids[N_REQ-2: 0] | current_ready[N_REQ-2:0];

    // use previosly generated mask on the input valids
    logic [N_REQ-1:0] masked_valid;
    assign masked_valid = mask_higher_pri_valids & input_valid;

    logic [N_REQ-1:0] priority_encoder_upper_grant;
    logic [N_REQ-1:0] priority_encoder_lower_grant;

    // initialise first input of the two priority encoders
    assign priority_encoder_upper_grant[0] = masked_valid[0];
    assign priority_encoder_lower_grant[0] = input_valid[0];

    // generate the remaining priority outputs
    genvar i;
    generate
        for (i = 1; i < N_REQ; i++) begin
            assign priority_encoder_upper_grant[i] = masked_valid[i] && ~| priority_encoder_upper_grant[i-1:0];
            assign priority_encoder_lower_grant[i] = input_valid[i] && ~| priority_encoder_lower_grant[i-1:0];
        end
    endgenerate

    // check if the upper priority has generated a valid ready signal
    logic upper_grant_eqz;
    assign upper_grant_eqz = ~| priority_encoder_upper_grant;

    // decide between the upper or lower priority using the above signal
    assign next_ready = priority_encoder_upper_grant | (priority_encoder_lower_grant & {N_REQ{upper_grant_eqz}});

endmodule