`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    // allwoin
    input                          ds_allowin     ,
    // br_bus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    // to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    // output        inst_sram_en   ,
    // output [ 3:0] inst_sram_wen  ,
    // output [31:0] inst_sram_addr ,
    // output [31:0] inst_sram_wdata,
    // input  [31:0] inst_sram_rdata,
    // sram like interface
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,

    input  [31:0] cp0_epc,
    input         ws_eret,
    input         ws_ex
);

reg         fs_valid;
wire        fs_ready_go;
reg         fs_ready_go_r;
wire        fs_allowin;
wire        pf_ready_go;
reg         pf_ready_go_r;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;
reg  [31:0] nextpc_r;

reg         inst_sram_req_r;
reg         inst_sram_rdata_r_valid;
reg  [31:0] inst_sram_rdata_r;

reg         bd_done;
wire        ds_br_or_jump_op;
reg         ds_br_or_jump_op_r;
wire        br_stall;
wire        br_taken;
reg         br_taken_r;
wire [31:0] br_target;
reg  [31:0] br_target_r;
assign {ds_br_or_jump_op, br_stall, br_taken, br_target} = br_bus;

wire        fs_ex;
wire        fs_bd;
wire [ 4:0] fs_excode;
wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_bd,       // 70:70
                       fs_ex,       // 69:69
                       fs_excode,   // 68:64
                       fs_inst,     // 63:32
                       fs_pc        // 31:0
                      };

reg        ws_ex_r;
reg        ws_eret_r;
reg        cancel;

// pre-IF stage
always @(posedge clk) begin
    if (reset) begin
        bd_done <= 1'b1;
    end
    else if (ws_ex || ws_eret) begin
        bd_done <= 1'b1;
    end
    else if (ds_br_or_jump_op_r && fs_valid) begin
        bd_done <= 1'b1;
    end
    else if (ds_br_or_jump_op) begin
        bd_done <= 1'b0;
    end
end
always @(posedge clk) begin
    if (reset) begin
        ds_br_or_jump_op_r = 1'b0;
    end
    else if (ws_ex || ws_eret) begin
        ds_br_or_jump_op_r = 1'b0;
    end
    else if (fs_to_ds_valid && ds_allowin) begin
        ds_br_or_jump_op_r = 1'b0;
    end
    else if (ds_br_or_jump_op) begin
        ds_br_or_jump_op_r = 1'b1;
    end
end
always @(posedge clk) begin
    if (reset) begin
        br_taken_r <= 1'b0;
    end
    else if (ws_ex || ws_eret) begin
        br_taken_r <= 1'b0;
    end
    else if (br_taken && !br_stall) begin
        br_taken_r <= 1'b1;
    end
    else if (to_fs_valid && fs_allowin) begin
        br_taken_r <= 1'b0;
    end
end
always @(posedge clk) begin
    if (reset) begin
        br_target_r <= 32'b0;
    end
    else if (br_taken && !br_stall) begin
        br_target_r <= br_target;
    end
end

always @(posedge clk) begin
    if (reset) begin
        ws_ex_r <= 1'b0;
    end
    else if (ws_ex) begin
        ws_ex_r <= 1'b1;
    end
    else if (to_fs_valid && fs_allowin) begin
        ws_ex_r <= 1'b0;
    end
end
always @(posedge clk) begin
    if (reset) begin
        ws_eret_r <= 1'b0;
    end
    else if (ws_eret) begin
        ws_eret_r <= 1'b1;
    end
    else if (to_fs_valid && fs_allowin) begin
        ws_eret_r <= 1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        nextpc_r <= seq_pc;
    end
    else if (ws_ex) begin
        nextpc_r <= 32'hbfc00380;
    end
    else if (ws_eret) begin
        nextpc_r <= cp0_epc;
    end
    else if (br_taken && !br_stall && bd_done && !ds_br_or_jump_op) begin
        nextpc_r <= br_target;
    end
    else if (to_fs_valid && fs_allowin) begin
        nextpc_r <= nextpc;
    end
end

always @(posedge clk) begin
    if (reset) begin
        pf_ready_go_r <= 1'b1;
    end
    else if (inst_sram_req && inst_sram_addr_ok)begin
        pf_ready_go_r <= 1'b1;
    end
    else if (to_fs_valid && fs_allowin)begin
        pf_ready_go_r <= 1'b0;
    end
end
assign pf_ready_go  = pf_ready_go_r;
assign to_fs_valid  = ~reset && pf_ready_go;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = ws_ex_r      ? 32'hbfc00380 :
                      ws_eret_r    ? cp0_epc      :
                      br_taken_r   ? br_target_r  :
                                     seq_pc;

// assign inst_sram_en    = to_fs_valid && fs_allowin;
// assign inst_sram_wen   = 4'h0;
// assign inst_sram_addr  = nextpc;
// assign inst_sram_wdata = 32'b0;

always @(posedge clk) begin
    if (reset) begin
        inst_sram_req_r <= 1'b0;
    end
    else if (to_fs_valid && fs_allowin) begin
        inst_sram_req_r <= 1'b1;
    end
    else if (inst_sram_req && inst_sram_addr_ok)begin
        inst_sram_req_r <= 1'b0;
    end
end

assign inst_sram_req = inst_sram_req_r && ~br_stall;
assign inst_sram_wr = 1'b0;
assign inst_sram_size = 2'h2;
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr = nextpc_r;
assign inst_sram_wdata = 32'b0;

// IF stage
always @(posedge clk) begin
    if (reset) begin
        fs_ready_go_r <= 1'b0;
    end
    else if (fs_to_ds_valid && ds_allowin) begin
        fs_ready_go_r <= 1'b0;
    end
    else if (inst_sram_data_ok && !cancel && !ws_ex && !ws_eret) begin
        fs_ready_go_r <= 1'b1;
    end
end
assign fs_ready_go    = fs_ready_go_r;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;

always@(posedge clk) begin
    if (reset) begin
        cancel <= 1'b0;
    end
    else if (inst_sram_data_ok) begin
        cancel <= 1'b0;
    end
    else if (ws_ex || ws_eret) begin
        if (to_fs_valid || fs_allowin == 1'b0 && fs_ready_go == 1'b0) begin
            cancel <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (ws_ex || ws_eret) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  // trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

always @(posedge clk) begin
    if (reset) begin
        inst_sram_rdata_r <= 32'b0;
    end
    else if (inst_sram_data_ok) begin
        inst_sram_rdata_r <= inst_sram_rdata;
    end
end

always@(posedge clk)begin
    if(reset)begin
        inst_sram_rdata_r_valid <= 1'b0;
    end
    else if(ws_eret || ws_ex) begin
        inst_sram_rdata_r_valid <= 1'b0;
    end
    else if(fs_valid && inst_sram_data_ok)begin
        inst_sram_rdata_r_valid <= 1'b1;
    end
    else if(fs_to_ds_valid && ds_allowin)begin
        inst_sram_rdata_r_valid <= 1'b0;
    end
end
assign fs_inst = inst_sram_rdata_r_valid ? inst_sram_rdata_r : inst_sram_rdata;

// exception judge
wire   addr_error;
assign addr_error  = (fs_pc[1:0] != 2'b0);
assign fs_ex       = fs_valid && addr_error;
assign fs_bd       = ds_br_or_jump_op_r;
assign fs_excode   = {5{fs_ex}} & `EX_ADEL;

endmodule
