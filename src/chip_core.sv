// SPDX-FileCopyrightText: © 2025 XXX Authors
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module chip_core #(
    parameter NUM_INPUT_PADS,
    parameter NUM_BIDIR_PADS,
    parameter NUM_ANALOG_PADS
    )(
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif
    
    input  wire clk,       // clock
    input  wire rst_n,     // reset (active low)
    
    input  wire [NUM_INPUT_PADS-1:0] input_in,   // Input value
    output wire [NUM_INPUT_PADS-1:0] input_pu,   // Pull-up
    output wire [NUM_INPUT_PADS-1:0] input_pd,   // Pull-down

    input  wire [NUM_BIDIR_PADS-1:0] bidir_in,   // Input value
    output wire [NUM_BIDIR_PADS-1:0] bidir_out,  // Output value
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,   // Output enable
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,   // Input type (0=CMOS Buffer, 1=Schmitt Trigger)
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,   // Slew rate (0=fast, 1=slow)
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,   // Input enable
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,   // Pull-up
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,   // Pull-down

    inout  wire [NUM_ANALOG_PADS-1:0] analog  // Analog
);

    // See here for usage: https://gf180mcu-pdk.readthedocs.io/en/latest/IPs/IO/gf180mcu_fd_io/digital.html
    
    // Disable pull-up and pull-down for input
    assign input_pu = '0;
    assign input_pd = '0;

    // Set the bidir as the TT inputs, bidirs, outputs
    assign bidir_oe[7:0] = '0;
    assign bidir_out[7:0] = '0;

    assign bidir_oe[26:16] = '1;
    assign bidir_cs = '0;
    assign bidir_sl = '0;
    assign bidir_ie[26:0] = ~bidir_oe[26:0];
    assign bidir_pu = '0;
    assign bidir_pd[26:0] = '0;

    assign bidir_ie[NUM_BIDIR_PADS-1:27] = '0;
    assign bidir_oe[NUM_BIDIR_PADS-1:27] = '0;
    assign bidir_pd[NUM_BIDIR_PADS-1:27] = '1;
    assign bidir_out[NUM_BIDIR_PADS-1:27] = '0;

    wire [15:8] uio_in;
    generate
    for (genvar i=8; i<16; i++) begin : bidir_inputs
        assign uio_in[i] = bidir_oe[i] ? bidir_out[i] : bidir_in[i];
    end
    endgenerate

    tt_um_MichaelBell_tinyQV tt(
        .ui_in(bidir_in[7:0]),
        .uo_out(bidir_out[24:16]),
        .uio_in(uio_in),
        .uio_out(bidir_out[15:8]),
        .uio_oe(bidir_oe[15:8]),
        .ena(1'b1),
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(input_in[0]),
        .uart_tx(bidir_out[25]),
        .uart_rts(bidir_out[26])
    );

endmodule

`default_nettype wire
