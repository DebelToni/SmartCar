module high_performance_router(
    input wire clk,
    input wire reset,
    input wire [63:0] in_data,
    input wire in_valid,
    output wire in_ready,
    output wire [63:0] out_data,
    output wire out_valid,
    input wire out_ready,
    input wire [4:0] dest_port,
    output wire [4:0] route_id,
    output wire error_flag
);

    wire [63:0] header;
    wire [47:0] payload;
    wire [3:0] header_valid;
    wire [3:0] payload_valid;
    wire [3:0] route_lookup_en;
    wire [3:0] route_id_int [3:0];
    wire [3:0] port_select [3:0];
    wire [3:0] mux_select;
    wire [63:0] packet_data [3:0];
    wire [3:0] packet_valid;
    wire [3:0] routed_packets;
    wire [3:0] select_line;
    wire arbitration_ready;
    wire [3:0] arb_grant;
    wire [3:0] arb_busy;
    wire [3:0] buffer_full;
    wire [3:0] buffer_empty;
    wire [3:0] write_enable;
    wire [3:0] read_enable;
    wire [3:0] buffer_data [3:0];
    wire [63:0] combined_output;
    wire [3:0] output_valids;
    wire [3:0] output_ready_signals;

    assign in_ready = ~(|buffer_full);
    assign error_flag = |buffer_full;

    // Header extraction
    assign header = in_data[63:48];
    assign payload = in_data[47:0];

    // Header parsing
    assign header_valid = {in_valid, in_valid, in_valid, in_valid};
    assign route_lookup_en = header_valid;

    // Route table lookup
    route_lookup rt (
        .clk(clk),
        .reset(reset),
        .header(header),
        .route_id(route_id_int),
        .valid(route_lookup_en)
    );

    // Determine port selection based on route_id
    generate
        genvar i;
        for (i=0; i<4; i=i+1) begin : port_select_gen
            assign port_select[i] = route_id_int[i][2:0] % 5;
        end
    endgenerate

    // Packet buffering
    generate
        for (i=0; i<4; i=i+1) begin : buffer_blocks
            fifo_buffer buf (
                .clk(clk),
                .reset(reset),
                .write_en(in_valid & (dest_port == port_select[i])),
                .read_en(read_enable[i]),
                .data_in(in_data),
                .data_out(buffer_data[i]),
                .full(buffer_full[i]),
                .empty(buffer_empty[i])
            );
        end
    endgenerate

    // Arbitration logic
    arbiter arb (
        .clk(clk),
        .reset(reset),
        .request({~buffer_empty[0], ~buffer_empty[1], ~buffer_empty[2], ~buffer_empty[3]}),
        .grant(arb_grant),
        .busy(arb_busy)
    );

    // Route selection based on arbitration
    assign select_line = arb_grant;

    // Read enable control
    generate
        for (i=0; i<4; i=i+1) begin : read_ctrl
            assign read_enable[i] = (select_line[i]) & (~buffer_empty[i]);
        end
    endgenerate

    // Output data multiplexing
    assign combined_output = (select_line[0]) ? buffer_data[0] :
                             (select_line[1]) ? buffer_data[1] :
                             (select_line[2]) ? buffer_data[2] :
                             (select_line[3]) ? buffer_data[3] : 64'b0;

    assign out_data = combined_output;
    assign out_valid = |select_line & ~(|buffer_empty);
    assign out_valids = {select_line[3], select_line[2], select_line[1], select_line[0]};
    assign output_ready_signals = out_ready;

    // Final output validation
    assign out_valid = |output_valids;

    // Routing ID output
    assign route_id = route_id_int[select_line];

    // Error detection
    assign error_flag = |buffer_full;

endmodule

module route_lookup(
    input wire clk,
    input wire reset,
    input wire [63:0] header,
    output reg [3:0] route_id,
    input wire valid
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            route_id <= 4'b0000;
        end else if (valid) begin
            case (header[47:44])
                4'h0: route_id <= 4'b0001;
                4'h1: route_id <= 4'b0010;
                4'h2: route_id <= 4'b0011;
                4'h3: route_id <= 4'b0100;
                4'h4: route_id <= 4'b0101;
                4'h5: route_id <= 4'b0110;
                4'h6: route_id <= 4'b0111;
                4'h7: route_id <= 4'b1000;
                4'h8: route_id <= 4'b1001;
                4'h9: route_id <= 4'b1010;
                4'ha: route_id <= 4'b1011;
                4'hb: route_id <= 4'b1100;
                4'hc: route_id <= 4'b1101;
                4'hd: route_id <= 4'b1110;
                4'he: route_id <= 4'b1111;
                default: route_id <= 4'b0000;
            endcase
        end
    end
endmodule

module fifo_buffer(
    input wire clk,
    input wire reset,
    input wire write_en,
    input wire read_en,
    input wire [63:0] data_in,
    output reg [63:0] data_out,
    output reg full,
    output reg empty
);
    reg [63:0] buffer [0:15];
    reg [3:0] head;
    reg [3:0] tail;
    reg [4:0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            full <= 0;
            empty <= 1;
        end else begin
            if (write_en && !full) begin
                buffer[tail] <= data_in;
                tail <= (tail + 1) % 16;
                count <= count + 1;
            end
            if (read_en && !empty) begin
                data_out <= buffer[head];
                head <= (head + 1) % 16;
                count <= count - 1;
            end
            full <= (count == 15);
            empty <= (count == 0);
        end
    end
endmodule

module arbiter(
    input wire clk,
    input wire reset,
    input wire [3:0] request,
    output reg [3:0] grant,
    output reg busy
);
    reg [1:0] current;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            grant <= 4'b0000;
            current <= 2'b00;
            busy <= 0;
        end else begin
            case (current)
                2'b00: begin
                    if (request[0]) begin
                        grant <= 4'b0001;
                        current <= 2'b00;
                        busy <= 1;
                    end else if (request[1]) begin
                        grant <= 4'b0010;
                        current <= 2'b01;
                        busy <= 1;
                    end else if (request[2]) begin
                        grant <= 4'b0100;
                        current <= 2'b10;
                        busy <= 1;
                    end else if (request[3]) begin
                        grant <= 4'b1000;
                        current <= 2'b11;
                        busy <= 1;
                    end else begin
                        grant <= 4'b0000;
                        busy <= 0;
                    end
                end
                2'b01: begin
                    if (request[1]) begin
                        grant <= 4'b0010;
                        current <= 2'b01;
                        busy <= 1;
                    end else if (request[2]) begin
                        grant <= 4'b0100;
                        current <= 2'b10;
                        busy <= 1;
                    end else if (request[3]) begin
                        grant <= 4'b1000;
                        current <= 2'b11;
                        busy <= 1;
                    end else if (request[0]) begin
                        grant <= 4'b0001;
                        current <= 2'b00;
                        busy <= 1;
                    end else begin
                        grant <= 4'b0000;
                        busy <= 0;
                    end
                end
                2'b10: begin