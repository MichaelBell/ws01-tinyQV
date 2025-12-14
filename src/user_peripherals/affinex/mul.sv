module mul
# (
    parameter WIDTH = 16
)
(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      start,
    input  logic signed [  WIDTH-1:0] a_i, b_i,
    output logic signed [2*WIDTH-1:0] result_o,
    output logic                      done, busy
);

    // Internal registers
    logic signed [  WIDTH-1:0] a_reg, b_reg;
    logic signed [2*WIDTH-1:0] acc;
    logic        [        5:0] bit_cnt;
    logic                      sign;
    logic                      busy_reg;
    logic                      done_reg;
    logic                      start_reg;

    assign sign = a_i[WIDTH-1] ^ b_i[WIDTH-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg      <= 0;
            b_reg      <= 0;
            acc        <= 0;
            bit_cnt    <= 0;
            busy_reg   <= 0;
            done_reg   <= 0;
            start_reg  <= 1'b0;
        end
        else begin
            done_reg   <= 1'b0;
            start_reg <= start;

            if (start_reg && !busy_reg) begin
                a_reg   <= (a_i[WIDTH-1]) ? ~a_i+1 : a_i;
                b_reg   <= (b_i[WIDTH-1]) ? ~b_i+1 : b_i;
                acc       <= 0;
                bit_cnt   <= 0;
                busy_reg  <= 1'b1;
            end
            else if (busy_reg) begin
                if (b_reg[0])
                    acc <= acc + (a_reg <<< bit_cnt);

                bit_cnt <= bit_cnt + 1;
                b_reg   <= b_reg >>> 1;

                if (bit_cnt == WIDTH - 1) begin
                    busy_reg <= 1'b0;
                    done_reg <= 1'b1;
                end
            end
        end
    end

    assign result_o = sign ? ~acc+1 : acc;
    assign done     = done_reg;
    assign busy     = busy_reg;

endmodule
