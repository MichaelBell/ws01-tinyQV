/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 41 and change tqvp_example to your chosen module name.
module tqvp_CORDIC
    #(parameter ITERATIONS=12,
      parameter FIXED_WIDTH=16)
     (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [5:0]   address,      // Address within this peripheral's address space
    input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    output        user_interrupt  // Dedicated interrupt request for this peripheral
);
    // register 0 : {is_rotating, mode, start}
    // register 1 : A
    // register 2 : B
    // register 3 : {shift}
    // register 4 : out 1
    // register 5 : out 2
    // register 6 : status. 0 ready to be run, 1 busy, 2 completed

    // mode = 0 : CIRCULAR
    // mode = 1 : LINEAR 
    // mode = 2 : HYPERBOLIC


    reg [1:0] mode_reg;
    reg is_rotating_reg, start_reg;

    reg [FIXED_WIDTH-1:0]           A, B;
    reg [$clog2(FIXED_WIDTH):0]   shift;

    wire [FIXED_WIDTH-1:0]          out1, out2;
    wire                            done;     
    reg                             done_reg;                        

    reg [1:0] status_reg;
    // Implement a 32-bit read/write register at address 0
    generate
    always @(posedge clk) begin
        if (!rst_n) 
        begin
            mode_reg <= 0;
            is_rotating_reg <= 0;
            start_reg <= 0;
            A <= 0;
            B <= 0;
            shift <= 11;
            done_reg <= 0;
            status_reg <= 0;
        end 
        else
         begin
            done_reg <= done_reg | done;
            start_reg <= 0;
            if (done)
            begin
                status_reg <= 2;
            end

            if (address == 6'h0) 
            begin
               if (data_write_n != 2'b11)
               begin
                    mode_reg <= data_in[2:1];
                    is_rotating_reg <= data_in[3];
                    start_reg <= data_in[0];

                    if (data_in[0] && !done)
                    begin
                        status_reg <= 1;
                    end
               end
            end
            else if (address == 6'h1)
            begin
                if (data_write_n != 2'b11)              A[7:0]   <= data_in[7:0];
                if (data_write_n[1] != data_write_n[0]) A[15:8]  <= data_in[15:8];
                
                /*
                if (FIXED_WIDTH > 16) begin : A_hi_bits
                if (data_write_n == 2'b10)              A[FIXED_WIDTH-1:16] <= data_in[FIXED_WIDTH-1:16];                
                end
                */
            end
            else if (address == 6'h2)
            begin
                if (data_write_n != 2'b11)              B[7:0]   <= data_in[7:0];
                if (data_write_n[1] != data_write_n[0]) B[15:8]  <= data_in[15:8];
                /*
                if (FIXED_WIDTH > 16) begin : B_hi_bits
                if (data_write_n == 2'b10)              B[FIXED_WIDTH-1:16] <= data_in[FIXED_WIDTH-1:16];                
                end
                */
            end
            else if (address == 6'h3)
            begin
                if (data_write_n != 2'b11) 
                    shift <= data_in[$clog2(FIXED_WIDTH):0];
            end
        end
    end
    endgenerate

    CORDIC #(
    .ITERATIONS(ITERATIONS),
    .FIXED_WIDTH(FIXED_WIDTH)
    )cordic_module (.clk(clk),
                    .rst_n(rst_n),
                    .start(start_reg),
                    .is_rotating(is_rotating_reg), 
                    .mode(mode_reg),                // `CIRCULAR_MODE`, `LINEAR_MODE`, `HYPERBOLIC_MODE`
                    .alpha_one_left_shift(shift),   // on which bit, the 1.0 is stored 
                                                    // for example for WIDTH=16 and this value set to 10
                                                    // 1.0 = 0000 0100 0000 0000

                    .A(A),                          // first input to module
                    .B(B),                          // second input to module
                    .out1(out1),                    // first ouput
                    .out2(out2),                    // second output
                    .done(done)                     // 1-cycle pulse on finish, pluggable to interrupt ? 
);

    // Address 0 reads the example data register.  
    // Address 4 reads ui_in
    // All other addresses read 0.
    assign data_out = (address == 6'h0) ? 32'hbadcaffe :
                      (address == 6'h4) ?  { {(32-FIXED_WIDTH){1'b0}}, out1} :
                      (address == 6'h5) ?  { {(32-FIXED_WIDTH){1'b0}}, out2} :
                      (address == 6'h6) ? {30'b0, status_reg} :
                      32'h0;

    // All reads complete in 1 clock
    assign data_ready = 1;
    
    // interrupt generated on the done signal
    assign user_interrupt = done;

    // List all unused inputs to prevent warnings
    // data_read_n is unused as none of our behaviour depends on whether
    // registers are being read.
    wire _unused = &{data_read_n, 1'b0};
    wire _unused2 = &{ui_in, 1'b0}; // ui_in is unused as we don't use the PMOD inputs in this example
    wire _unused3 = &data_in[31:16];

    // or show something useful, e.g. status bits:
    assign uo_out = {6'b0, status_reg};
endmodule
