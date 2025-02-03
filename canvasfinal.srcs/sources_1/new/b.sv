module vga_test (
    input wire clk, reset,
    input wire btnu, btnl, btnd, btnr, btnc,  // Button inputs
    input wire draw_mode_toggle,             // Input for toggling 1x1 or 3x3 draw mode (W14)
    input wire [2:0] sw,                     // Switch inputs for color selection
    output wire hsync, vsync,
    output wire [11:0] rgb
);

    // Internal signals
    wire video_on;
    wire [9:0] x, y;

    // Cursor position registers
    reg [9:0] cursor_x = 320; // Initial cursor X position
    reg [9:0] cursor_y = 240; // Initial cursor Y position

    // Scroll timer
    reg [19:0] scroll_timer = 0;
    wire scroll_tick;

    always @(posedge clk or posedge reset)
        if (reset)
            scroll_timer <= 0;
        else
            scroll_timer <= scroll_timer + 1;

    assign scroll_tick = (scroll_timer == 20'd999_999); // Adjust value for scroll speed

    // Cursor movement logic with bounds checking
    always @(posedge clk or posedge reset)
        if (reset) begin
            cursor_x <= 320; // Center X
            cursor_y <= 240; // Center Y
        end else if (scroll_tick) begin
            if (btnu && cursor_y > 20) cursor_y <= cursor_y - 1; // Move up, stop at top
            if (btnd && cursor_y < 479) cursor_y <= cursor_y + 1; // Move down, stop at bottom
            if (btnl && cursor_x > 10) cursor_x <= cursor_x - 1; // Move left, stop at left edge
            if (btnr && cursor_x < 639) cursor_x <= cursor_x + 1; // Move right, stop at right edge
        end

    // Reduced resolution memory: 40x30 grid
    reg [11:0] pixel_memory [0:39][0:29]; // 40x30 grid (each cell represents a 16x16 pixel block)
    reg [11:0] draw_color;                // Selected drawing color

    // Drawing mode toggle
    reg draw_mode = 0; // 0: off, 1: on

    // Toggle draw mode on button press
    always @(posedge clk or posedge reset)
        if (reset)
            draw_mode <= 0;
        else if (btnc)
            draw_mode <= ~draw_mode;

    // Initialize memory
    integer i, j;
    initial begin
        for (i = 0; i < 40; i = i + 1) begin
            for (j = 0; j < 30; j = j + 1) begin
                pixel_memory[i][j] = 12'hFFF; // Initialize to white
            end
        end
    end

    // Drawing logic
    always @(posedge clk or posedge reset)
        if (reset) begin
            // Clear pixel memory to white
            for (i = 0; i < 40; i = i + 1) begin
                for (j = 0; j < 30; j = j + 1) begin
                    pixel_memory[i][j] <= 12'hFFF;
                end
            end
        end else if (draw_mode) begin
            // Map cursor position to grid coordinates
            integer grid_x = cursor_x / 16;
            integer grid_y = cursor_y / 16;

            // Draw based on draw_mode_toggle (1x1 or 3x3 area)
            if (draw_mode_toggle) begin
                // Draw a 3x3 area
                integer dx, dy;
                for (dx = -1; dx <= 1; dx = dx + 1) begin
                    for (dy = -1; dy <= 1; dy = dy + 1) begin
                        if ((grid_x + dx) >= 0 && (grid_x + dx) < 40 && 
                            (grid_y + dy) >= 0 && (grid_y + dy) < 30) begin
                            pixel_memory[grid_x + dx][grid_y + dy] <= draw_color;
                        end
                    end
                end
            end else begin
                // Draw a 1x1 area
                if (grid_x >= 0 && grid_x < 40 && grid_y >= 0 && grid_y < 30) begin
                    pixel_memory[grid_x][grid_y] <= draw_color;
                end
            end
        end

    // Cursor dimensions
    localparam CURSOR_WIDTH = 2;
    localparam CURSOR_LENGTH = 10;

    // Determine if the current pixel is part of the cursor
    wire cursor_active = (
        (x >= cursor_x - CURSOR_WIDTH && x <= cursor_x + CURSOR_WIDTH && 
         y >= cursor_y - CURSOR_LENGTH && y <= cursor_y + CURSOR_LENGTH) || // Vertical line
        (x >= cursor_x - CURSOR_LENGTH && x <= cursor_x + CURSOR_LENGTH && 
         y >= cursor_y - CURSOR_WIDTH && y <= cursor_y + CURSOR_WIDTH)    // Horizontal line
    );

    // Select color based on switches
    always @* begin
        case (sw)
            3'b000: draw_color = 12'hF00; // Red
            3'b001: draw_color = 12'h0F0; // Green
            3'b010: draw_color = 12'h00F; // Blue
            3'b011: draw_color = 12'hFF0; // Yellow
            3'b100: draw_color = 12'hF0F; // Magenta
            3'b101: draw_color = 12'h0FF; // Cyan
            3'b110: draw_color = 12'h000; // Black
            3'b111: draw_color = 12'h880; // Orange (instead of white)
            default: draw_color = 12'h880; // Default to orange
        endcase
    end

    // Instantiate vga_sync module
    vga_sync vga_sync_unit (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .p_tick(),
        .x(x),
        .y(y)
    );

    // Map pixel coordinates to grid and fetch color
    wire [11:0] pixel_color;
    wire [5:0] grid_x = x / 16;
    wire [5:0] grid_y = y / 16;
    assign pixel_color = pixel_memory[grid_x][grid_y];

    // Generate video output
    assign rgb = video_on ? (cursor_active ? 12'h0F0 : pixel_color) : 12'h000; // Green cursor, pixel memory background

endmodule