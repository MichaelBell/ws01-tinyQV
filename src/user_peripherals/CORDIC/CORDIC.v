`define CIRCULAR_MODE   2'b00 
`define LINEAR_MODE     2'b01 
`define HYPERBOLIC_MODE 2'b10

module CORDIC #(
    parameter ITERATIONS  = 9,
    parameter FIXED_WIDTH = 16
)(
    input                                   clk,
    input                                   rst_n,
    input                                   start,
    input                                   is_rotating,            // LINEAR: 1=multiply, 0=divide
    input [1:0]                             mode,                   // `CIRCULAR_MODE / `LINEAR_MODE / `HYPERBOLIC_MODE
    input [$clog2(FIXED_WIDTH):0]         alpha_one_left_shift,

    input [FIXED_WIDTH-1:0]                 A,
    input [FIXED_WIDTH-1:0]                 B,
    output reg [FIXED_WIDTH-1:0]            out1,
    output reg [FIXED_WIDTH-1:0]            out2,
    output reg                              done
);

    // ---------------- helpers ----------------
    function [FIXED_WIDTH-1:0] abs_tc;
        input signed [FIXED_WIDTH-1:0] v;
        begin
            abs_tc = v[FIXED_WIDTH-1] ? (~v + {{(FIXED_WIDTH-1){1'b0}},1'b1}) : v;
        end
    endfunction

    // Width needed to index bits [0..FIXED_WIDTH-1]
    localparam integer IDX_W = (FIXED_WIDTH <= 1) ? 1 : $clog2(FIXED_WIDTH);

    // MSB index (priority encoder); returns highest set bit (0..FIXED_WIDTH-1),
    // or 0 if v == 0
    function [IDX_W:0] msb_index;
        input [FIXED_WIDTH-1:0] v;
        integer i;
        reg hit;
        begin
            msb_index = {(IDX_W+1){1'b0}};
            hit = 1'b0;
            // scan from MSB down; capture the first '1'
            for (i = FIXED_WIDTH-1; i >= 0; i = i - 1) begin
                if (!hit && v[i]) begin
                    msb_index = i[IDX_W:0]; // truncate i to IDX_W safely
                    hit = 1'b1;               // stop updating after first hit
                end
            end
        end
    endfunction

    // ---------------- state ----------------
    localparam integer ITER_W = $clog2(ITERATIONS);


    reg      [ITER_W:0] iteration;
    wire     last_iter = (iteration == (ITERATIONS-1));

    reg running;
    reg [1:0] mode_latched;
    reg       rot_latched;

    reg  signed [FIXED_WIDTH-1:0] x, y, z;
    wire signed  [FIXED_WIDTH-1:0] next_x, next_y, next_z;

    // shift used by the iter stage (0..W-1)
    wire [ITER_W:0] sh_u = iteration;
    wire [ITER_W:0] sh   = (sh_u > (FIXED_WIDTH-1)) ? (FIXED_WIDTH-1) : sh_u;

    // σ via MSB (cheaper): rotate: ~z[MSB]; vector: y[MSB]
    wire is_sigma_positive = rot_latched ? ~z[FIXED_WIDTH-1] : y[FIXED_WIDTH-1];

    // “1.0” in Z-scale and linear delta (single shifter)
    wire       sh_le_alpha = (sh <= alpha_one_left_shift);
    wire [$clog2(FIXED_WIDTH):0] diff = alpha_one_left_shift - sh[$clog2(FIXED_WIDTH):0];
    wire signed [FIXED_WIDTH-1:0] alpha_linear = sh_le_alpha ? ({{(FIXED_WIDTH-1){1'b0}},1'b1} <<< diff) : '0;

    // Combinational atan LUT (signed Q2.14)
    wire signed [FIXED_WIDTH-1:0] delta_theta_atan;
    CORDIC_angles_ROM_comb #(
        .FIXED_WIDTH(FIXED_WIDTH),
        .ITERATIONS (ITERATIONS)
    ) angles_rom (
        .which_angle(sh),
        .angle_out  (delta_theta_atan)
    );

    // combinational atanh LUT (signed Q3.13)
    wire signed [FIXED_WIDTH-1:0] delta_theta_atanh;
    CORDIC_atanh_ROM_comb #(.FIXED_WIDTH(FIXED_WIDTH),
                            .ITERATIONS(ITERATIONS)) atanh_angles_rom(.which_angle(sh),
                                                                      .angle_out(delta_theta_atanh));

    // delta_z select
    reg signed [FIXED_WIDTH-1:0] delta_z;
    always @* begin
        case (mode_latched)
            `CIRCULAR_MODE:   delta_z = delta_theta_atan;
            `LINEAR_MODE:     delta_z = alpha_linear;
            `HYPERBOLIC_MODE: delta_z = delta_theta_atanh;
            default:          delta_z = {{(FIXED_WIDTH-1){1'b0}},1'b1}; // placeholder for hyperbolic
        endcase
    end

    // One-iter-per-cycle datapath
    CORDIC_iteration #(
        .FIXED_WIDTH(FIXED_WIDTH),
        .ITERATIONS (ITERATIONS)
    ) iter_stage (
        .x(x), .y(y), .z(z),
        .shift(sh),
        .delta_z(delta_z),
        .is_sigma_positive(is_sigma_positive),
        .mode(mode_latched),
        .next_x(next_x), .next_y(next_y), .next_z(next_z)
    );

    // K^-1 for circular rotate (Q2.14)
    localparam signed [FIXED_WIDTH-1:0] K_INV_Q = 16'sd9949;

    // K for hyperbolic rotation
    localparam signed [FIXED_WIDTH-1:0] K_HYP = 16'b0100110101001000; // 1.20751953125 in Q2.14
    //localparam signed [FIXED_WIDTH-1:0] K_HYP = 16'b0010011010100100; // 1.20751953125 in Q3.13

    // ---------------- single-cycle prescaler ----------------
    localparam integer K_W = $clog2(FIXED_WIDTH);
    reg  [K_W:0] k_lat;  // latched prescale for post-scaling

    // Compute k for LINEAR:
    //   multiply (rot=1): want |z| < 2*one_q  ->  k = max(0, msb(|z|) - (alpha_one_left_shift + 1))
    //   divide   (rot=0): want |y| < 2|x|     ->  k = max(0, msb(|y|) - msb(|x|))
    wire [K_W:0] msb_z = msb_index(abs_tc($signed(B)));
    wire [K_W:0] msb_y = msb_index(abs_tc($signed(B)));
    wire [K_W:0] msb_x = msb_index(abs_tc($signed(A)));

    wire [K_W:0] k_mul = (msb_z >= (alpha_one_left_shift + 1)) ? (msb_z - alpha_one_left_shift) : {(K_W+1){1'b0}};
    wire [K_W:0] k_div = (msb_y > msb_x) ? (msb_y - msb_x) : {(K_W+1){1'b0}};

    wire [K_W:0] k_comb =(mode == `LINEAR_MODE) ? (is_rotating ? k_mul : k_div) : {(K_W+1){1'b0}};

    // hyperbolic mode : does iteration needs repeating 
    // hyperbolic mode requires repeition on i = 4, and i = 13 
    wire repeat_signal = (mode == `HYPERBOLIC_MODE && ((iteration == 4) || (iteration == 13)));
    reg skipped_already;

    // set the outputs based on the mode
    always @(*)
    begin
        // default values to avoid latches
        out1 = 0;
        out2 = 0;

        case (mode)
            `CIRCULAR_MODE:
            begin
                if (rot_latched)
                begin
                    out1 = x; // cos
                    out2 = y; // sin
                end 
                else 
                begin
                    out1 = x; // r 
                    out2 = z; // angle
                end
            end
            `LINEAR_MODE:
            begin
               if (rot_latched) begin
                    // product = y << k
                    out1 = $signed(y) <<< k_lat;
                    out2 = z; // residual
                end 
                else 
                begin
                    // quotient = z << k
                    out1 = $signed(z) <<< k_lat;
                    out2 = y; // residual
                end                
            end
            `HYPERBOLIC_MODE:
            begin
                if (rot_latched)
                begin
                    out1 = x;
                    out2 = y;
                end 
                else 
                begin
                    out1 = x;
                    out2 = z;
                end
            end
            default:
            begin
                out1 = x;
                out2 = z;
            end 
        endcase
    end

    // ---------------- FSM ----------------
    always @(posedge clk) begin
        if (!rst_n) begin
            running          <= 1'b0;
            iteration        <= 'd0;
            mode_latched     <= 2'b00;
            rot_latched      <= 1'b0;
            x                <= '0; 
            y                <= '0; 
            z                <= '0;
            done             <= 1'b0;
            k_lat            <= {(K_W+1){1'b0}};
            skipped_already  <= 0;
        end else begin
            done             <= 1'b0;

            if (start && !running) begin
                mode_latched    <= mode;
                rot_latched     <= is_rotating;
                k_lat           <= k_comb;       // latch k (constant-latency prescale)
                iteration       <= 'd0;
                running         <= 1'b1;
                skipped_already <= 0;

                case (mode)
                  `CIRCULAR_MODE: begin
                      if (is_rotating) begin
                          z <= $signed(A);
                          x <= K_INV_Q; 
                          y <= '0;
                      end else begin
                          x <= $signed(A); 
                          y <= $signed(B); 
                          z <= '0;
                      end
                  end
                  `LINEAR_MODE: begin
                      if (is_rotating) begin
                          x <= $signed(A);
                          y <= '0;
                          // prescale z in one cycle (arith shift)
                          z <= $signed($signed(B) >>> k_comb);
                      end else begin
                          x <= $signed(A);
                          // prescale y in one cycle (arith shift)
                          y <= $signed($signed(B) >>> k_comb);
                          z <= '0;
                      end
                  end
                  `HYPERBOLIC_MODE: begin
                    iteration <= 'd1;
                    if (is_rotating)
                    begin
                        z <= $signed(A);
                        x <= K_HYP;
                        y <= 0;                        
                    end
                    else 
                    begin
                        x <= $signed(A);
                        y <= $signed(B);
                        z <= '0;
                    end
                  end
                  default: begin
                      x <= '0; y <= '0; z <= '0;
                  end
                endcase

            end else if (running) begin
                // perform iteration
                x <= next_x; 
                y <= next_y;
                z <= next_z;

                if (last_iter) 
                begin
                    running <= 1'b0;
                    // post-scale once (barrel left shift) and finish
                    done <= 1'b1;
                    skipped_already <= 0;

                end 
                else
                begin
                    if (skipped_already)
                    begin
                        skipped_already <= 0;
                        iteration <= iteration + 1'b1;
                    end
                    
                    else if (repeat_signal)
                    begin
                        iteration <= iteration;
                        skipped_already <= 1;
                    end

                    else
                        iteration <= iteration + 1'b1;
                end
            end
        end
    end

endmodule
