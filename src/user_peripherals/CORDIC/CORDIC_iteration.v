`define CIRCULAR_MODE   2'b00 
`define LINEAR_MODE     2'b01 
`define HYPERBOLIC_MODE 2'b10


module CORDIC_iteration #(parameter FIXED_WIDTH = 16,
                          parameter ITERATIONS = 9)
                        (input signed  [FIXED_WIDTH-1:0] x,
                         input signed  [FIXED_WIDTH-1:0] y,
                         input signed  [FIXED_WIDTH-1:0] z,

                         input [$clog2(ITERATIONS):0] shift,
                         input signed [FIXED_WIDTH-1:0] delta_z,

                         input is_sigma_positive,
                         input [1:0] mode, 

                         output reg signed [FIXED_WIDTH-1:0] next_x,
                         output reg signed [FIXED_WIDTH-1:0] next_y,
                         output reg signed [FIXED_WIDTH-1:0] next_z);

        // clamp shift to [0 ... FIXED_WIDTH-1]
        //localparam integer SHIFT_W = $clog2(ITERATIONS);
        
        // if (FIXED_WIDTH == 16)
        // begin
        //    wire [7:0] sh = (shift > (FIXED_WIDTH-1)) ? (FIXED_WIDTH-1) : shift;
        //end
        //else 
        //begin
        wire [4:0] sh = shift;
        //end
        

        // precompute shifts once
        wire signed [FIXED_WIDTH-1:0] x_s = x >>> sh;
        wire signed [FIXED_WIDTH-1:0] y_s = y >>> sh;

        always @(*)
        begin
            // defaults to avoid the accidental latches
            next_x = {FIXED_WIDTH{1'b0}};
            next_y = {FIXED_WIDTH{1'b0}};
            next_z = {FIXED_WIDTH{1'b0}};

            case (mode)
                `CIRCULAR_MODE:
                begin
                    if (is_sigma_positive)
                    begin
                        next_x = x - y_s;
                        next_y = y + x_s; 
                        next_z = z - delta_z;
                    end
                    else 
                    begin 
                        next_x = x + y_s;
                        next_y = y - x_s; 
                        next_z = z + delta_z;
                    end
                end
                `LINEAR_MODE:
                begin
                    if (is_sigma_positive)
                    begin
                        next_x = x;
                        next_y = y + x_s;
                        next_z = z - delta_z;
                    end
                    else 
                    begin
                        next_x = x;
                        next_y = y - x_s;
                        next_z = z + delta_z;
                    end
                end

                `HYPERBOLIC_MODE:
                begin
                    if (is_sigma_positive)
                    begin
                        next_x = x + y_s;
                        next_y = y + x_s; 
                        next_z = z - delta_z;
                    end
                    else 
                    begin
                        next_x = x - y_s;
                        next_y = y - x_s;
                        next_z = z + delta_z;
                    end
                end

                default:
                begin
                    // keeps zeros
                end

            endcase 
        end
endmodule
