module CORDIC_atanh_ROM_comb #(parameter FIXED_WIDTH = 16,
                               parameter ITERATIONS = 9)
                               (
                                    input wire [$clog2(ITERATIONS):0] which_angle,
                                    output wire signed [FIXED_WIDTH-1:0] angle_out
                               );


    wire [$clog2(ITERATIONS):0] idx = (which_angle > (ITERATIONS-1)) ? (ITERATIONS-1) : which_angle;

    function [FIXED_WIDTH-1:0] atanh_lut;
        input [$clog2(ITERATIONS):0] i;

        begin 
            case(i)
                // Q2.14 
                'd1: atanh_lut     = 16'b0010001100101000;     // atanh(2^-1)
                'd2: atanh_lut     = 16'b0001000001011001;     // atanh(2^-2)
                'd3: atanh_lut     = 16'b0000100000001011;     // atanh(2^-3)
                'd4: atanh_lut     = 16'b0000010000000001;     // atanh(2^-4)
                'd5: atanh_lut     = 16'b0000001000000000;     // atanh(2^-5)
                'd6: atanh_lut     = 16'b0000000100000000;     // atanh(2^-6)
                'd7: atanh_lut     = 16'b0000000010000000;     // atanh(2^-7)
                'd8: atanh_lut     = 16'b0000000001000000;     // atanh(2^-8)
                'd9: atanh_lut     = 16'b0000000000100000;     // atanh(2^-9)
                'd10: atanh_lut    = 16'b0000000000010000;     // atanh(2^-10)
                'd11: atanh_lut    = 16'b0000000000001000;     // atanh(2^-11)
                default: atanh_lut = 16'b0000000000000100;     // atanh(2^-12)
            endcase 
        end 
    endfunction

    assign angle_out = $signed(atanh_lut(idx));

endmodule

