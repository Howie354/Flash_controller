module spi_flash #(
    parameter CMD_WD  = 8,
    parameter ADDR_WD = 24,
    parameter DATA_WD = 8,
    parameter TOL_WD  = 40
)(
    input                clk,
    input                rst_n,

    input [TOL_WD-1 : 0] cmd_in,
    input                cmd_vld,
    output               cmd_rdy,

    output               sclk,
    output               cs_n,
    
    inout                si,
    inout                so,
    inout                wp,
    inout                sio3
);

// FSM state
localparam IDLE   = 4'b0000,
           CMD    = 4'b0001,
           RDIF   = 4'b0011,
           WRSR   = 4'b0010,
           PP     = 4'b0110,
           READ   = 4'b0111,
           READ2  = 4'b0101,
           PP4    = 4'b0100,
           BURST  = 4'b1100,
           READ4  = 4'b1101,
           SE     = 4'b1111;

// chip select beats of different state
localparam CMD_CS   = 8,
           RDIF_CS  = 32,
           WRSR_CS  = 24,
           PP_CS    = 2080,
           READ_CS  = 48,
           READ2_CS = 40,
           PP4_CS   = 526,
           BURST_CS = 16,
           READ4_CS = 48,
           SE_CS    = 32;

localparam STA_WD = 4,
           CNT_WD = 12;

reg [TOL_WD-1 : 0] cmd_in_r;
reg [CNT_WD-1 : 0] cnt_r;
reg [STA_WD-1 : 0] cur_state;
reg [STA_WD-1 : 0] next_state;

reg cs_n;
reg si_en;
reg so_en;
reg io_en;

reg si_d;
reg so_d;
reg wp_d;
reg sio3_d;

wire si_y;
wire so_y;
wire wp_y;
wire sio3_y;

reg cmd_done;
reg rdif_done;
reg wrsr_done;
reg pp_done;
reg read_done;
reg read2_done;
reg pp4_done;
reg burst_done;
reg read4_done;
reg se_done;

wire cmd_fire;

assign cmd_fire = cmd_vld && cmd_rdy;
assign cmd_rdy  = (cur_state == IDLE);

assign si     = si_en ? si_d : 1'bz;
assign si_y   = si;
assign so     = so_en ? so_d : 1'bz;
assign so_y   = so;
assign wp     = io_en ? wp_d : 1'bz;
assign wp_y   = wp;
assign sio3   = io_en ? sio3_d : 1'bz;
assign sio3_y = sio3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cmd_in_r <= 'b0;
    end
    else begin
        cmd_in_r <= cmd_in;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cur_state <= IDLE;
    end
    else begin
        cur_state <= next_state;
    end
end

always @(*) begin
    next_state = IDLE;
    case (cur_state)
        IDLE: next_state = cmd_fire ? CMD : IDLE;
        CMD:  begin
            if (!cmd_done) begin
                next_state = CMD;
            end
            else begin
                case (cmd_in_r[TOL_WD-1 : TOL_WD-CMD_WD])
                    8'h9F: next_state = RDIF;
                    8'h05: next_state = RDIF;
                    8'h15: next_state = RDIF;
                    8'h01: next_state = WRSR;
                    8'h02: next_state = PP;
                    8'h03: next_state = READ;
                    8'hBB: next_state = READ2;
                    8'h38: next_state = PP4;
                    8'h77: next_state = BURST;
                    8'hEB: next_state = READ4;
                    8'h20: next_state = SE;
                endcase
            end
        end
        RDIF:  next_state = rdif_done  ? IDLE : RDIF;
        WRSR:  next_state = wrsr_done  ? IDLE : WRSR;
        PP:    next_state = pp_done    ? IDLE : PP;
        READ:  next_state = read_done  ? IDLE : READ;
        WRSR:  next_state = wrsr_done  ? IDLE : WRSR;
        PP4:   next_state = pp4_done   ? IDLE : PP4;
        BURST: next_state = burst_done ? IDLE : BURST;
        READ2: next_state = read2_done ? IDLE : READ2;
        READ4: next_state = read4_done ? IDLE : READ4;
        SE:    next_state = se_done    ? IDLE : SE;  
    endcase
end

always @(*) begin
    cmd_done   = 1'b0;
    rdif_done  = 1'b0;
    wrsr_done  = 1'b0;
    pp_done    = 1'b0;
    read_done  = 1'b0;
    read2_done = 1'b0;
    pp4_done   = 1'b0;
    burst_done = 1'b0;
    read4_done = 1'b0;
    se_done    = 1'b0;
    case (cur_state)
        CMD:   cmd_done   = (cnt_r == CMD_CS - 1);
        RDIF:  rdif_done  = (cnt_r == RDIF_CS - 1);
        WRSR:  wrsr_done  = (cnt_r == WRSR_CS - 1);
        PP:    pp_done    = (cnt_r == PP_CS - 1);
        READ:  read_done  = (cnt_r == READ_CS - 1);
        READ2: read2_done = (cnt_r == READ2_CS - 1);
        PP4:   pp4_done   = (cnt_r == PP4_CS - 1);
        BURST: burst_done = (cnt_r == BURST_CS - 1);
        READ4: read4_done = (cnt_r == READ4_CS - 1);
        SE:    se_done    = (cnt_r == SE_CS - 1);
    endcase
end

// control signal
always @(*) begin
    cs_n  = 1'b1;
    si_en = 1'b1;
    so_en = 1'b0;
    io_en = 1'b0;
    case (cur_state)
        CMD:   cs_n = 1'b0;
        RDIF:  cs_n = 1'b0;
        WRSR:  cs_n = 1'b0;
        PP:    cs_n = 1'b0;
        READ:  cs_n = 1'b0;
        BURST: cs_n = 1'b0;
        SE:    cs_n = 1'b0;
        READ2: begin
            cs_n  = 1'b0;
            si_en = (cnt_r < 24) ? 1'b1 : 1'b0;
            so_en = (cnt_r < 24) ? 1'b1 : 1'b0;
        end
        PP4:   begin
            cs_n  = 1'b0;
            si_en = 1'b1;
            so_en = 1'b1;
            io_en = 1'b1;
        end
        READ4: begin
            cs_n  = 1'b0;
            si_en = (cnt_r < 16) ? 1'b1 : 1'b0;
            so_en = (cnt_r < 16) ? 1'b1 : 1'b0;
            io_en = (cnt_r < 16) ? 1'b1 : 1'b0;
        end
    endcase
end

assign sclk = ~clk && !cs_n;

// data path
always @(*) begin
    si_d   = cmd_in_r[TOL_WD-1-cnt_r];
    so_d   = 1'b0;
    wp_d   = 1'b0;
    sio3_d = 1'b0;
    case (cur_state)
        READ2: begin
            if (cnt_r < 20) begin
                si_d = cmd_in_r[TOL_WD + 6 - (cnt_r << 1)];
                so_d = cmd_in_r[TOL_WD + 7 - (cnt_r << 1)];
            end
        end
        READ4: begin
            if (cnt_r < 14) begin
                si_d   = cmd_in_r[TOL_WD + 20 - (cnt_r << 2)];
                so_d   = cmd_in_r[TOL_WD + 21 - (cnt_r << 2)];
                wp_d   = cmd_in_r[TOL_WD + 22 - (cnt_r << 2)];
                sio3_d = cmd_in_r[TOL_WD + 23 - (cnt_r << 2)];
            end
        end
        PP:    begin
            if (cnt_r > 31) begin
                si_d = cmd_in_r[7 - cnt_r % 8];
            end
        end
        PP4:   begin
            if (cnt_r < 14) begin 
                si_d   = cmd_in_r[TOL_WD + 20 - (cnt_r << 2)];
                so_d   = cmd_in_r[TOL_WD + 21 - (cnt_r << 2)];
                wp_d   = cmd_in_r[TOL_WD + 22 - (cnt_r << 2)];
                sio3_d = cmd_in_r[TOL_WD + 23 - (cnt_r << 2)];
            end
            else begin
                si_d   = (cnt_r % 2) ? cmd_in_r[0] : cmd_in_r[4];
                so_d   = (cnt_r % 2) ? cmd_in_r[1] : cmd_in_r[5];
                wp_d   = (cnt_r % 2) ? cmd_in_r[2] : cmd_in_r[6];
                sio3_d = (cnt_r % 2) ? cmd_in_r[3] : cmd_in_r[7];
            end
        end
    endcase
end

// counter logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n || cur_state == IDLE) begin
        cnt_r <= 'b0;
    end
    else begin
        cnt_r <= cnt_r + 1'b1;
    end
end

endmodule

