`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    // forward
    output [`ES_FWD_BUS_WD -1:0]   es_fwd_bus
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire        es_inst_mult  ,
wire        es_inst_multu ,
wire        es_inst_div   ,
wire        es_inst_divu  ,
wire        es_inst_mfhi  ,
wire        es_inst_mflo  ,
wire        es_inst_mthi  ,
wire        es_inst_mtlo  ,
wire [11:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm;
wire        es_src2_is_uimm;
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
assign {
        es_inst_mult   ,  // 144:144
        es_inst_multu  ,  // 143:143
        es_inst_div    ,  // 142:142
        es_inst_divu   ,  // 141:141
        es_inst_mfhi   ,  // 140:140
        es_inst_mflo   ,  // 139:139
        es_inst_mthi   ,  // 138:138
        es_inst_mtlo   ,  // 137:137
        es_alu_op      ,  // 136:125
        es_load_op     ,  // 124:124
        es_src1_is_sa  ,  // 123:123
        es_src1_is_pc  ,  // 122:122
        es_src2_is_imm ,  // 121:121
        es_src2_is_uimm,  // 120:120
        es_src2_is_8   ,  // 119:119
        es_gr_we       ,  // 118:118
        es_mem_we      ,  // 117:117
        es_dest        ,  // 116:112
        es_imm         ,  // 111:96
        es_rs_value    ,  // 95 :64
        es_rt_value    ,  // 63 :32
        es_pc             // 31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;

wire        es_res_from_mem;

assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_alu_result  ,  //63:32
                       es_pc             //31:0
                      };


assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm ? {{16{es_imm[15]}}, es_imm[15:0]} :
                     es_src2_is_uimm? {16'd0,            es_imm[15:0]} :
                     es_src2_is_8   ? 32'd8 :
                                      es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );

assign data_sram_en    = 1'b1;
assign data_sram_wen   = (es_mem_we && es_valid) ? 4'hf : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rt_value;

// es forward bus
wire es_block;
wire es_block_valid;
assign es_block = es_gr_we;
assign es_block_valid  = es_block && es_valid;
assign es_fwd_bus = {es_load_op && es_valid,   // 38:38
                     es_block_valid        ,   // 37:37
                     es_dest               ,   // 36:32
                     es_alu_result             // 31:0
                     };// es forward bus

endmodule
