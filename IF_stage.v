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

// pre-IF stage
assign pf_ready_go  = ~br_stall;
assign to_fs_valid  = ~reset && pf_ready_go;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = 
                      ws_ex    ? 32'hbfc00380 :
                      ws_eret  ? cp0_epc      :
                      br_taken ? br_target    :
                                 seq_pc; 

// IF stage
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && !ws_eret && !ws_ex;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

assign inst_sram_en    = to_fs_valid && fs_allowin && pf_ready_go;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

// exception judge
wire   addr_error;
assign addr_error  = (fs_pc[1:0] != 2'b0);
assign fs_ex       = fs_valid && addr_error;
assign fs_bd       = ds_br_or_jump_op;
assign fs_excode   = {5{fs_ex}} & `EX_ADEL;

endmodule
