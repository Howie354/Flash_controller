`timescale 1ns / 100ps

module tb_spi_flash;

localparam CMD_WD  = 8,
           ADDR_WD = 24,
           DATA_WD = 8,
           TOL_WD  = 40;

reg                clk;
reg                rst_n;
reg [TOL_WD-1 : 0] cmd_in;
reg                cmd_vld;
wire               cmd_rdy;

wire               cs_n;
wire               sclk;
wire               si;
wire               so;
wire               wp;
wire               sio3;

wire cmd_fire = cmd_vld && cmd_rdy;

initial begin
    $dumpfile("test.vcd");
    $dumpvars;
end


initial begin
    clk = 0;
    forever begin
        #6.2;
        clk = ~clk;
    end
end

initial begin
    rst_n = 0;
    #3;
    rst_n = 1;
    #1115000;
    $finish;
end

initial begin
    #800000 cmd_in = {8'h9F, 24'h0, 8'h0};   cmd_vld = 1;  //RDID
    #600    cmd_in = {8'h05, 24'h0, 8'h0};   cmd_vld = 1;  //RDSR
    #600    cmd_in = {8'h15, 24'h0, 8'h0};   cmd_vld = 1;  //RDCR
    #600    cmd_in = {8'h06, 24'h0, 8'h0};   cmd_vld = 1;  //WREN
    #150    cmd_in = {8'h38, 24'h40, 8'hA5}; cmd_vld = 1;  //PP4
    #309000 cmd_in = {8'h03, 24'h40, 8'h0};  cmd_vld = 1;  //READ
    #750    cmd_in = {8'hBB, 24'h40, 8'h0};  cmd_vld = 1;  //READ2
    #750    cmd_in = {8'hEB, 24'h40, 8'h0};  cmd_vld = 1;  //READ4
    #750    cmd_in = {8'h77, 24'h40, 8'h0};  cmd_vld = 1;  //BURST
    #750    cmd_in = {8'h20, 24'h40, 8'h0};  cmd_vld = 1;  //SE
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cmd_vld <= 1'b0;
    end
    else if (cmd_rdy && cmd_vld) begin
        cmd_vld <= 1'b0;
    end
end

spi_flash #(
    .CMD_WD(CMD_WD),
    .ADDR_WD(ADDR_WD),
    .DATA_WD(DATA_WD),
    .TOL_WD(TOL_WD)
) u_spi_flash(
    .clk(clk),
    .rst_n(rst_n),
    .cmd_in(cmd_in),
    .cmd_vld(cmd_vld),
    .cmd_rdy(cmd_rdy),
    .sclk(sclk),
    .cs_n(cs_n),
    .si(si),
    .so(so),
    .wp(wp),
    .sio3(sio3)
);

MX25L6436F MX25L(
    .SCLK(sclk),
    .CS(cs_n),
    .SI(si),
    .SO(so),
    .WP(wp),
    .SIO3(sio3)
);

endmodule
    
