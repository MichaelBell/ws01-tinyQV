module CORDIC_angles_ROM_comb #(
    parameter FIXED_WIDTH = 16,
    parameter ITERATIONS  = 9
)(
    // 5-bits is a more then iterations but  
    input  wire [$clog2(ITERATIONS):0] which_angle,                   
    output wire signed [FIXED_WIDTH-1:0] angle_out
);
    wire [$clog2(ITERATIONS):0] idx = (which_angle > (ITERATIONS-1)) ? (ITERATIONS-1) : which_angle;

    function [FIXED_WIDTH-1:0] atan_lut;
        input [$clog2(ITERATIONS):0] i;
        begin
            case (i)
                'd0:        atan_lut = 16'b0011001001000100; // atan(2^-0)
                'd1:        atan_lut = 16'b0001110110101100; // atan(2^-1)
                'd2:        atan_lut = 16'b0000111110101110; // atan(2^-2)
                'd3:        atan_lut = 16'b0000011111110101; // atan(2^-3)
                'd4:        atan_lut = 16'b0000001111111111; // atan(2^-4)
                'd5:        atan_lut = 16'b0000001000000000; // atan(2^-5)
                'd6:        atan_lut = 16'b0000000100000000; // atan(2^-6)
                'd7:        atan_lut = 16'b0000000010000000; // atan(2^-7)
                'd8:        atan_lut = 16'b0000000001000000; // atan(2^-8)
                'd9:        atan_lut = 16'b0000000000100000; // atan(2^-9)
                'd10:       atan_lut = 16'b0000000000010000; // atan(2^-10)
                default:    atan_lut = 16'b0000000000001000; // default case
            endcase
        end
    endfunction

    assign angle_out = $signed(atan_lut(idx));
endmodule
