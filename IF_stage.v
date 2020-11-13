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
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         ds_br_or_jump_op;
wire         br_stall;
wire         br_taken;
wire [ 31:0] br_target;
wire pf_ready_go;
// reg [`BR_BUS_WD - 1:0] br_bus_r;
// reg          bd_done;
// reg          br_bus_valid;
// always @(posedge clk) begin
//     if (reset) begin
//         br_bus_r <= `BR_BUS_WD'b0;
//         br_bus_valid <= 1'b0;
//     end
//     else if (pf_ready_go && fs_allowin) begin
//         br_bus_valid <= 1'b0;
//     end
//     else if (ds_allowin) begin
//         br_bus_r <= br_bus;
//         br_bus_valid <= 1'b1;
//     end
// end
// always @(posedge clk) begin
//     if (reset) begin
//         bd_done <= 1'b0;
//     end
//     else if (ds_allowin) begin
//         bd_done <= 1'b0;
//     end
//     else if(~br_stall && br_taken && fs_valid)begin
//         bd_done <= 1'b1;
//     end
// end

assign {ds_br_or_jump_op, br_stall, br_taken, br_target} = br_bus;
reg ds_br_or_jump_op_r;
always @(posedge clk) begin
    if (reset) begin
        ds_br_or_jump_op_r = 1'b0;
    end
    else if (ds_br_or_jump_op) begin
        ds_br_or_jump_op_r = 1'b1;
    end
    else if (fs_to_ds_valid && ds_allowin) begin
        ds_br_or_jump_op_r = 1'b0;
    end
end

reg        pf_ready_go_r;
reg        inst_sram_req_r;
reg [31:0] inst_sram_rdata_r;
reg        fs_ready_go_r;
reg        cancel_rdata_r;
reg        nextpc_r_valid;
reg [31:0] nextpc_r;

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

// pre-IF stage
always @(posedge clk) begin
    if (reset) begin
        pf_ready_go_r <= 1'b0;
    end
    else if (inst_sram_req && inst_sram_addr_ok)begin
        pf_ready_go_r <= 1'b1;
    end
    else if (to_fs_valid && fs_allowin)begin
        pf_ready_go_r <= 1'b0;
    end
end
always @(posedge clk) begin
    if (reset) begin
        nextpc_r_valid <= 1'b0;
    end
    else if (to_fs_valid && fs_allowin && ~ws_ex && ~ws_eret) begin
        nextpc_r_valid <= 1'b0;
    end
    // else if (to_fs_valid && fs_allowin && ~br_stall)begin
    //     nextpc_r_valid <= 1'b0;
    // end
    else if (!nextpc_r_valid && !br_stall) begin
        nextpc_r_valid <= 1'b1;
    end

    if (reset) begin
        nextpc_r <= 32'b0;
    end
    else if (ws_ex) begin
        nextpc_r <= 32'hbfc00380;
    end
    else if (ws_eret) begin
        nextpc_r <= cp0_epc;
    end
    else if (!nextpc_r_valid) begin
        nextpc_r <= nextpc;
    end
end

assign pf_ready_go  = pf_ready_go_r;// ~br_stall && (inst_sram_req & inst_sram_addr_ok);
assign to_fs_valid  = ~reset;   // && pf_ready_go;
assign seq_pc       = {fs_pc[31:2], 2'b00} + 3'h4;
assign nextpc       = 
                      ws_ex    ? 32'hbfc00380 :
                      ws_eret  ? cp0_epc      :
                      br_taken ? br_target    :
                                 seq_pc; 

always @(posedge clk) begin
    if (reset) begin
        cancel_rdata_r <= 1'b0;
    end
    else if ((ws_ex || ws_eret) && !inst_sram_data_ok) begin
        if(pf_ready_go || fs_allowin == 1'b0 && fs_ready_go == 1'b0)begin
            cancel_rdata_r <= 1'b1;
        end
    end
    else if (inst_sram_data_ok) begin
        cancel_rdata_r <= 1'b0;
    end
end

// IF stage
always @(posedge clk) begin
    if (reset) begin
        fs_ready_go_r <= 1'b0;
    end
    else if (inst_sram_data_ok) begin
        fs_ready_go_r <= 1'b1;
    end
    else if (fs_to_ds_valid && ds_allowin) begin
        fs_ready_go_r <= 1'b0;
    end
end
assign fs_ready_go    = fs_ready_go_r && !cancel_rdata_r;// && ((br_bus_valid && pf_ready_go == 1'b0) ? 1'b0 : 1'b1);
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && !ws_eret && !ws_ex && !cancel_rdata_r;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    // else if (cancel_rdata_r) begin
    //     fs_valid <= 1'b0;
    // end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc_r_valid ? nextpc_r : nextpc;
    end
end

// assign inst_sram_en    = to_fs_valid && fs_allowin;
// assign inst_sram_wen   = 4'h0;
// assign inst_sram_addr  = nextpc;
// assign inst_sram_wdata = 32'b0;

always @(posedge clk) begin
    if (reset) begin
        inst_sram_req_r <= 1'b0;
    end
    else if (~br_stall && to_fs_valid && fs_allowin) begin
        inst_sram_req_r <= 1'b1;
    end
    else if (inst_sram_req && inst_sram_addr_ok)begin
        inst_sram_req_r <= 1'b0;
    end
end

assign inst_sram_req = inst_sram_req_r; // TODO
assign inst_sram_wr = 1'b0;
assign inst_sram_size = 2'h2;
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr = fs_pc; // TODO
assign inst_sram_wdata = 32'b0;

always @(posedge clk) begin
    if (reset) begin
        inst_sram_rdata_r <= 32'b0;
    end
    else if (inst_sram_data_ok) begin
        inst_sram_rdata_r <= inst_sram_rdata & {32{~cancel_rdata_r && ~ws_ex && ~ws_eret}};
    end
end
assign fs_inst = inst_sram_rdata_r;

// exception judge
wire   addr_error;
assign addr_error  = (fs_pc[1:0] != 2'b0);
assign fs_ex       = fs_valid && addr_error;
assign fs_bd       = ds_br_or_jump_op_r;
assign fs_excode   = {5{fs_ex}} & `EX_ADEL;

endmodule
