module plugin_loader #(
    parameter MAX_PLUGINS = 16,
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire reset,
    input wire load_req,
    input wire [ADDR_WIDTH-1:0] plugin_addr,
    input wire [DATA_WIDTH-1:0] plugin_data_in,
    output reg load_ack,
    output reg [DATA_WIDTH-1:0] plugin_data_out,
    output reg busy,
    output reg error
);

    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        PROCESS,
        DONE
    } state_t;

    state_t current_state, next_state;

    reg [DATA_WIDTH-1:0] plugin_storage [0:MAX_PLUGINS-1];
    reg [ADDR_WIDTH-1:0] plugin_index;

    wire plugin_found;
    reg [DATA_WIDTH-1:0] temp_data;
    reg [3:0] init_counter;
    reg [3:0] process_counter;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            busy <= 0;
            load_ack <= 0;
            error <= 0;
            plugin_data_out <= 0;
            plugin_index <= 0;
            init_counter <= 0;
            process_counter <= 0;
            for (int i=0; i<MAX_PLUGINS; i++) begin
                plugin_storage[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                busy = 0;
                load_ack = 0;
                error = 0;
                if (load_req) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                busy = 1;
                plugin_index = 0;
                plugin_found = 0;
                for (int i=0; i<MAX_PLUGINS; i++) begin
                    if (plugin_storage[i][ADDR_WIDTH-1:0] == plugin_addr) begin
                        plugin_found = 1;
                        plugin_index = i;
                    end
                end
                if (plugin_found) begin
                    plugin_storage[plugin_index] <= plugin_data_in;
                    load_ack = 1;
                    next_state = PROCESS;
                end else begin
                    error = 1;
                    next_state = DONE;
                end
            end
            PROCESS: begin
                busy = 1;
                process_counter = 0;
                temp_data = plugin_storage[plugin_index];
                next_state = PROCESS;
                if (process_counter < 4'd10) begin
                    process_counter = process_counter + 1;
                end else begin
                    plugin_data_out = temp_data ^ 32'hA5A5A5A5;
                    next_state = DONE;
                end
            end
            DONE: begin
                busy = 0;
                load_ack = 0;
                error = 0;
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (current_state == PROCESS && process_counter < 4'd10) begin
            process_counter <= process_counter + 1;
        end
    end

endmodule