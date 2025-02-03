module ps2_mouse_interface (
    input wire clk, reset,
    input wire ps2_clk, ps2_data,
    output reg [9:0] x_mov, y_mov,
    output reg left_btn, right_btn,
    output reg middle_btn,
    output reg valid
);
    // Mouse communication state machine and packet decoding

    reg [10:0] shift_reg;
    reg [3:0] bit_count;
    reg [1:0] byte_count;
    reg [7:0] data[2:0]; // Buffer for 3 mouse bytes

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            shift_reg <= 0;
            bit_count <= 0;
            byte_count <= 0;
            valid <= 0;
        end else begin
            if (ps2_clk == 0) begin // Falling edge of ps2_clk
                shift_reg <= {ps2_data, shift_reg[10:1]};
                bit_count <= bit_count + 1;

                if (bit_count == 10) begin // Byte received
                    data[byte_count] <= shift_reg[8:1]; // Save 8 data bits
                    bit_count <= 0;
                    byte_count <= byte_count + 1;

                    if (byte_count == 2) begin
                        // Decode the packet after receiving 3 bytes
                        left_btn <= data[0][0];
                        right_btn <= data[0][1];
                        middle_btn <= data[0][2];
                        x_mov <= {data[0][4], data[1]}; // Sign extension
                        y_mov <= {data[0][5], data[2]}; // Sign extension
                        valid <= 1;
                        byte_count <= 0;
                    end
                end
            end
        end
    end
endmodule