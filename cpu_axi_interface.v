module cpu_axi_interface(
    input       clk,
    input       resetn,

    // inst sram like interface
    // master: cpu, slave: interface
    input         inst_sram_req    ,
    input         inst_sram_wr     ,
    input  [ 1:0] inst_sram_size   ,
    input  [ 3:0] inst_sram_wstrb  ,
    input  [31:0] inst_sram_addr   ,
    input  [31:0] inst_sram_wdata  ,
    output reg [31:0] inst_sram_rdata  ,
    output reg        inst_sram_addr_ok,
    output reg        inst_sram_data_ok,

    // data sram like interface 
    // master: cpu, slave: interface
    input         data_sram_req    ,
    input         data_sram_wr     ,
    input  [ 1:0] data_sram_size   ,
    input  [ 3:0] data_sram_wstrb  ,
    input  [31:0] data_sram_addr   ,
    input  [31:0] data_sram_wdata  ,
    output reg [31:0] data_sram_rdata  ,
    output reg        data_sram_addr_ok,
    output reg        data_sram_data_ok,

    // axi interface
    // master: interface, slave: axi
    // ar: acquire reading channels
    output reg [ 3:0] arid   ,
    output reg [31:0] araddr ,
    output [ 7:0] arlen  ,
    output reg [ 2:0] arsize ,
    output [ 1:0] arburst,
    output [ 1:0] arlock ,
    output [ 3:0] arcache,
    output [ 2:0] arprot ,
    output reg        arvalid,
    input         arready,
    // r: reading response channels
    input  [ 3:0] rid    ,
    input  [31:0] rdata  ,
    input  [ 1:0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output reg    rready ,
    // aw: acquire writing channels
    output [ 3:0] awid   ,
    output reg [31:0] awaddr ,
    output [ 7:0] awlen  ,
    output reg [ 2:0] awsize ,
    output [ 1:0] awburst,
    output [ 1:0] awlock ,
    output [ 3:0] awcache,
    output [ 2:0] awprot ,
    output reg        awvalid,
    input         awready,
    // w: write data channels
    output [ 3:0] wid    ,
    output reg [31:0] wdata  ,
    output reg [ 3:0] wstrb  ,
    output        wlast  ,
    output reg        wvalid ,
    input         wready ,
    // b: writing response channels
    input  [ 3:0] bid    ,
    input  [ 1:0] bresp  ,
    input         bvalid ,
    output reg    bready
);


//////////////////////////
////         ar       ////
//////////////////////////
`define AR_STATE_NUM 4
reg [`AR_STATE_NUM - 1: 0] ar_state;
reg [`AR_STATE_NUM - 1: 0] ar_next_state;
parameter AR_IDLE = 4'b0001;
parameter AR_I_VALID = 4'b0010;
parameter AR_D_VALID = 4'b0100;
parameter AR_READY = 4'b1000;

always @(posedge clk) begin
    if (~resetn) begin
        ar_state <= AR_IDLE;
    end
    else begin
        ar_state <= ar_next_state;
    end
end
always @(*) begin
    case(ar_state) 
    AR_IDLE: begin
        if(inst_sram_req & ~inst_sram_wr)
            ar_next_state = AR_I_VALID;
        else if(data_sram_req & ~data_sram_wr)
            ar_next_state = AR_D_VALID;
        else
            ar_next_state = ar_state;
    end
    AR_D_VALID: begin
        if(arready)
            ar_next_state = AR_READY;
        else
            ar_next_state = ar_state;
    end
    AR_I_VALID: begin
        if(arready)
            ar_next_state = AR_READY;
        else
            ar_next_state = ar_state;
    end
    AR_READY: begin
        ar_next_state = AR_IDLE;
    end
    endcase
end

assign arlen = 8'b0;
assign arburst = 2'b1;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b0;

// reg [3:0] arid_r;
// reg [32:0] araddr_r
// reg arvalid_r
// reg arready_r
// reg [2:0]arsize_r
always @(posedge clk)begin
//arid
//araddr
//arvalid
//arready
//arsize
    case(ar_state)
    AR_IDLE: begin
        arid <= 4'b0;
        araddr <= 32'b0;
        arvalid <= 1'b0;
        arsize <= 3'b0;
        inst_sram_addr_ok <= 1'b0;
    end
    AR_D_VALID: begin
        arid <= 4'b1;
        araddr <= data_sram_addr;
        arvalid <= 1'b1;
        arsize <= {1'b0, data_sram_size};
    end
    AR_I_VALID: begin
        arid <= 4'b0;
        araddr <= inst_sram_addr;
        arvalid <= 1'b1;
        arsize <= {1'b0, inst_sram_size};
    end
    AR_READY: begin
        arid <= 4'b0;
        araddr <= 32'b0;
        arvalid <= 1'b0;
        arsize <= 3'b0;
        inst_sram_addr_ok <= 1'b1;
    end
    endcase
end
//////////////////////////
////         r        ////
//////////////////////////
`define R_STATE_NUM 4
reg [`R_STATE_NUM - 1: 0]r_state;
reg [`R_STATE_NUM - 1: 0]r_next_state;
parameter R_IDLE = 4'b0001;
parameter R_VALID = 4'b0010;
parameter R_READY = 4'b0100;
// parameter R_READY = 4'b1000;

always @(posedge clk) begin
    if(~resetn) begin
        r_state <= R_IDLE;
    end
    else begin
        r_state <= r_next_state;
    end
end
always @(*) begin
    case(r_state) 
    R_IDLE: begin
        if(arvalid && arready)
            r_next_state = R_VALID;
        else
            r_next_state = r_state;
    end
    R_VALID: begin
        // if(rready)
        //     r_next_state = R_READY;
        // else
        //     r_next_state = r_state;
        r_next_state = R_READY;
    end
    R_READY: begin
        // if(rlast)
        r_next_state = AR_IDLE;
        // else
        //     r_next_state = r_state;
    end
    endcase
end

always @(posedge clk)begin
//rid
//rdata
//rvalid
//rready
    case(r_state)
    R_IDLE: begin
        rready <= 1'b0;
        inst_sram_data_ok <= 1'b0;
        data_sram_data_ok <= 1'b0;
    end
    R_VALID: begin
        rready <= 1'b1;
    end
    R_READY: begin
        if (rid == 4'b0) begin
            inst_sram_data_ok <= 1'b1;
            inst_sram_rdata <= rdata;
        end
        else if (rid == 4'b1) begin
            data_sram_data_ok <= 1'b1;
            data_sram_rdata <= rdata;
        end
    end
    endcase
end

//////////////////////////
////         aw       ////
//////////////////////////

assign awid = 4'b1;
assign awlen = 8'b0;
assign awburst = 2'b1;
assign awlock = 2'b0;
assign awcache = 4'b0;
assign awprot = 3'b0;

`define AW_STATE_NUM 4
reg [`AW_STATE_NUM - 1: 0]aw_state;
reg [`AW_STATE_NUM - 1: 0]aw_next_state;
parameter AW_IDLE = 4'b0001;
parameter AW_VALID = 4'b0100;
parameter AW_READY = 4'b1000;

always @(posedge clk) begin
    if(~resetn) begin
        aw_state <= AW_IDLE;
    end
    else begin
        aw_state <= aw_next_state;
    end
end
always @(*) begin
    case(aw_state) 
    AW_IDLE: begin
        if(data_sram_req & data_sram_wr)
            aw_next_state = AW_VALID;
        else
            aw_next_state = aw_state;
    end
    AW_VALID: begin
        if(awready)
            aw_next_state = AW_READY;
        else
            aw_next_state = aw_state;
    end
    AW_READY: begin
        aw_next_state = AW_IDLE;
    end
    endcase
end

always @(posedge clk)begin
//awaddr
//awsize
//awvalid
//awready
    case(aw_state)
    AW_IDLE: begin
        awvalid <= 1'b0;
        awsize <= 3'b0;
        awaddr <= 32'b0;
        data_sram_addr_ok <= 1'b0;
    end
    AW_VALID: begin
        awvalid <= 1'b1;
        awsize <= {1'b0, data_sram_size};
        awaddr <= data_sram_addr;
    end
    AW_READY: begin
        awvalid <= 1'b0;
        awsize <= 3'b0;
        awaddr <= 32'b0;
        // data_sram_addr_ok <= 1'b1;
    end
    endcase
end
//////////////////////////
////        w&b       ////
//////////////////////////
`define WB_STATE_NUM 4
reg [`WB_STATE_NUM - 1: 0]wb_state;
reg [`WB_STATE_NUM - 1: 0]wb_next_state;
parameter WB_IDLE = 4'b0001;
parameter WB_VALID = 4'b0010;
parameter WB_READY = 4'b0100;
parameter WB_DONE = 4'b1000;
assign wid = 4'b1;
assign wlast = 1'b1;

always @(posedge clk) begin
    if(~resetn) begin
        wb_state <= WB_IDLE;
    end
    else begin
        wb_state <= wb_next_state;
    end
end
always @(*) begin
    case(wb_state) 
    WB_IDLE: begin
        if(data_sram_req & data_sram_wr)
            wb_next_state = WB_VALID;
        else
            wb_next_state = wb_state;
    end
    WB_VALID: begin
        if(wready)
            wb_next_state = WB_READY;
        else
            wb_next_state = wb_state;
    end
    WB_READY: begin
        if(bvalid)
            wb_next_state = WB_DONE;
        else
            wb_next_state = wb_state;
    end
    WB_DONE: begin
        // if(bvalid)
        wb_next_state = WB_DONE;
        // else
        //     wb_next_state = wb_state;
    end
    endcase
end

always @(posedge clk)begin

//wvalid
//bready
//wdata
//wstrb
    case(wb_state)
    WB_IDLE: begin
        wvalid <= 1'b0;
        bready <= 1'b0;
        wdata <= 32'b0;
        wstrb <= 4'b0;
        data_sram_data_ok <= 1'b0;
    end
    WB_VALID: begin
        wvalid <= 1'b1;
    end
    WB_READY: begin
        wdata <= data_sram_wdata;
        wstrb <= data_sram_wstrb;
        data_sram_addr_ok <= 1'b1;
    end
    WB_DONE: begin
        bready <= 1'b1;
        data_sram_data_ok <= 1'b1;
    end
    endcase
end

endmodule