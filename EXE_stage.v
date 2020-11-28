`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    // allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    // from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    // to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    // output        data_sram_en   ,
    // output [ 3:0] data_sram_wen  ,
    // output [31:0] data_sram_addr ,
    // output [31:0] data_sram_wdata,
    // sram like interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    // forward
    output [`ES_FWD_BUS_WD -1:0]   es_fwd_bus,

    input  es_data_valid,
    output es_ex,
    input  flush
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [11:0] es_alu_op      ;
wire        es_store_op    ;
wire        es_load_op     ;
wire        es_src1_is_sa  ;
wire        es_src1_is_pc  ;
wire        es_src2_is_imm ;
wire        es_src2_is_uimm;
wire        es_src2_is_8   ;
wire        es_gr_we       ;
wire [ 4:0] es_st_inst     ;
wire [ 6:0] es_ld_inst     ;
wire [ 7:0] es_md_inst     ;
wire [ 4:0] es_dest        ;
wire [15:0] es_imm         ;
wire [31:0] es_rs_value    ;
wire [31:0] es_rt_value    ;
wire [31:0] es_pc          ;

// exception
wire [10:0] c0_bus          ;
wire        es_mtc0         ;
wire        es_mfc0         ;
wire        es_bd           ;
wire        ds_ex           ;
wire [ 4:0] ds_excode       ;
wire        es_overflow_inst;
// wire        es_ex           ;
wire [ 4:0] es_excode       ;
wire        es_alu_overflow ;
wire        es_overflow     ;
wire        es_ld_addr_error;
wire        es_st_addr_error;
wire [31: 0]ds_badvaddr     ;
wire [31: 0]es_badvaddr     ;
assign {
        ds_badvaddr     , //206:175
        c0_bus          , // 174:164
        es_bd           , // 163:163
        ds_ex           , // 162:162
        ds_excode       , // 161:157
        es_overflow_inst, // 156:156
        es_ld_inst      , // 155:149
        es_st_inst      , // 148:144
        es_md_inst      , // 143:136
        es_alu_op       , // 135:124
        es_load_op      , // 123:123
        es_src1_is_sa   , // 122:122
        es_src1_is_pc   , // 121:121
        es_src2_is_imm  , // 120:120
        es_src2_is_uimm , // 119:119
        es_src2_is_8    , // 118:118
        es_gr_we        , // 117:117
        es_dest         , // 116:112
        es_imm          , // 111:96
        es_rs_value     , // 95 :64
        es_rt_value     , // 63 :32
        es_pc             // 31 :0
       } = ds_to_es_bus_r;
assign es_mtc0 = c0_bus[9] && es_valid;
assign es_mfc0 = c0_bus[8] && es_valid;

wire [31:0] es_alu_src1    ;
wire [31:0] es_alu_src2    ;
wire [31:0] es_alu_result  ;
wire [31:0] es_res         ;
wire        es_res_from_mem;

// mul & div parts
wire        es_mult ;
wire        es_multu;
wire        es_div  ;
wire        es_divu ;
wire        es_mfhi ;
wire        es_mflo ;
wire        es_mthi ;
wire        es_mtlo ;
assign {es_mult     ,
        es_multu    ,
        es_div      ,
        es_divu     ,
        es_mfhi     ,
        es_mflo     ,
        es_mthi     ,
        es_mtlo
       } = es_md_inst;
reg  [31:0] hi      ;
reg  [31:0] lo      ;
wire [63:0] mul_res ;
wire [63:0] div_res ;
wire [63:0] divu_res;
// div
reg  div_work;
wire div_valid;
wire div_ready;
wire div_divisor_ready;
wire div_dividend_ready;
wire div_done;
// divu
reg  divu_work;
wire divu_valid;
wire divu_ready;
wire divu_divisor_ready;
wire divu_dividend_ready;
wire divu_done;

assign es_store_op = |es_st_inst;

assign es_res = es_mfhi ? hi :
                es_mflo ? lo :
                es_mtc0 ? es_rt_value :
                          es_alu_result;
assign es_overflow = es_alu_overflow && es_overflow_inst;
assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {
                       es_store_op    ,  // 128:128
                       es_badvaddr    ,  // 127:96
                       c0_bus         ,  // 95:85
                       es_bd          ,  // 84:84
                       es_ex          ,  // 83:83
                       es_excode      ,  // 82:78
                       es_ld_inst     ,  // 77:71
                       es_res_from_mem,  // 70:70
                       es_gr_we       ,  // 69:69
                       es_dest        ,  // 68:64
                       es_res         ,  // 63:32
                       es_pc             // 31:0
                      };

reg es_ready_go_r;
always @(posedge clk) begin
    if (reset) begin
        es_ready_go_r <= 1'b0;
    end
    else if (data_sram_req && data_sram_addr_ok)begin
        es_ready_go_r <= 1'b1;
    end
    else if (es_to_ms_valid && ms_allowin) begin
        es_ready_go_r <= 1'b0;
    end
end

assign es_ready_go    = !(es_div || es_divu || es_load_op || es_store_op) ||
                         (es_div && div_done) || (es_divu && divu_done) ||
                         ((es_load_op || es_store_op) && es_ready_go_r) ||
                         !es_data_valid;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go && !flush;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (flush) begin
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
    .alu_op     (es_alu_op      ),
    .alu_src1   (es_alu_src1    ),
    .alu_src2   (es_alu_src2    ),
    .alu_result (es_alu_result  ),
    .overflow   (es_alu_overflow)
    );

wire inst_sw;
wire inst_sh;
wire inst_sb;
wire inst_swl;
wire inst_swr;

assign {inst_sw ,
        inst_sh ,
        inst_sb ,
        inst_swl,
        inst_swr
        } = es_st_inst;

wire [ 1:0] mem_pos;
wire [31:0] st_data;
wire [31:0] swl_data;
wire [31:0] swr_data;
assign swl_data     = mem_pos == 2'd0 ? {24'b0, es_rt_value[31:24]} :
                      mem_pos == 2'd1 ? {16'b0, es_rt_value[31:16]} :
                      mem_pos == 2'd2 ? { 8'b0, es_rt_value[31: 8]} :
                      es_rt_value;
assign swr_data     = mem_pos == 2'd3 ? {es_rt_value[ 7: 0], 24'b0} :
                      mem_pos == 2'd2 ? {es_rt_value[15: 0], 16'b0} :
                      mem_pos == 2'd1 ? {es_rt_value[23: 0],  8'b0} :
                      es_rt_value;
assign st_data      = inst_sw ? es_rt_value            :
                      inst_sb ? {4{es_rt_value[ 7:0]}} :
                      inst_sh ? {2{es_rt_value[15:0]}} :
                      inst_swl? swl_data               :
                      inst_swr? swr_data               :
                                es_rt_value;

assign mem_pos = es_alu_result[1:0];
assign es_st_addr_error = (inst_sh & mem_pos[0])         // sh
                       || (inst_sw & (mem_pos != 2'b0)); // sw
wire        inst_lw ;
wire        inst_lb ;
wire        inst_lbu;
wire        inst_lh ;
wire        inst_lhu;
wire        inst_lwl;
wire        inst_lwr;
assign {inst_lw     ,
        inst_lb     ,
        inst_lbu    ,
        inst_lh     , 
        inst_lhu    ,
        inst_lwl    ,
        inst_lwr
       } = es_ld_inst;
assign es_ld_addr_error = (inst_lw & (mem_pos != 2'b00))         // lw
                       || ((inst_lh || inst_lhu) & mem_pos[0]);  // lhu & lh

// data sram
// assign data_sram_en   = 1'b1;
// assign data_sram_wen  = {4{es_valid && es_data_valid}} & (
//                         inst_sw ?  4'hf                                                                :
//                         inst_sh ? {                 {2{mem_pos[1]}},                 {2{~mem_pos[1]}}} :
//                         inst_sb ? {mem_pos == 2'd3, mem_pos == 2'd2, mem_pos == 2'd1, mem_pos == 2'd0} :
//                         inst_swl? {mem_pos == 2'd3, mem_pos[1]     , mem_pos!=2'd0  , 1'b1           } :
//                         inst_swr? {1'b1           , mem_pos != 2'd3, !mem_pos[1]    , mem_pos == 2'd0} :
//                                    4'b0);
// assign data_sram_addr  = {es_alu_result[31: 2], 2'b0};
// assign data_sram_wdata = st_data;

wire data_size_is_two;
wire data_size_is_one;
assign data_size_is_two = inst_sw  || inst_lw  ||
                        ((inst_lwl || inst_swl) && (mem_pos == 2'd2 || mem_pos == 2'd3)) ||
                        ((inst_lwr || inst_swr) && (mem_pos == 2'd0 || mem_pos == 2'd1));
assign data_size_is_one = inst_lh  || inst_sh  || inst_lhu ||
                        ((inst_lwl || inst_swl) && mem_pos == 2'd1) ||
                        ((inst_lwr || inst_swr) && mem_pos == 2'd2);
reg data_sram_req_r;
always @(posedge clk) begin
    if (reset) begin
        data_sram_req_r <= 1'b0;
    end
    else if (data_sram_req && data_sram_addr_ok)begin
        data_sram_req_r <= 1'b0;
    end
    else if (es_to_ms_valid && ms_allowin)begin
        data_sram_req_r <= 1'b0;
    end
    else if ((es_load_op || es_store_op) && ms_allowin) begin
        data_sram_req_r <= 1'b1;
    end
end

assign data_sram_req = data_sram_req_r && es_valid; // TODO
assign data_sram_wr = (|data_sram_wstrb);
assign data_sram_size = data_size_is_two ? 2'd2 :
                        data_size_is_one ? 2'd1 :
                                           2'd0 ;
assign data_sram_wstrb = {4{es_data_valid}} & (
                        inst_sw ?  4'hf                                                                :
                        inst_sh ? {                 {2{mem_pos[1]}},                 {2{~mem_pos[1]}}} :
                        inst_sb ? {mem_pos == 2'd3, mem_pos == 2'd2, mem_pos == 2'd1, mem_pos == 2'd0} :
                        inst_swl? {mem_pos == 2'd3, mem_pos[1]     , mem_pos!=2'd0  , 1'b1           } :
                        inst_swr? {1'b1           , mem_pos != 2'd3, !mem_pos[1]    , mem_pos == 2'd0} :
                                   4'b0);
assign data_sram_addr = {es_alu_result[31: 2], {2{~inst_lwl & ~inst_swl}} & es_alu_result[1:0]};
assign data_sram_wdata = st_data;

// es forward bus
wire es_block;
wire es_block_valid;
assign es_block = es_gr_we && !flush;
assign es_block_valid  = es_block && es_valid;
assign es_fwd_bus = {es_mfc0 && es_valid   ,   // 39:39
                     es_load_op && es_valid,   // 38:38
                     es_block_valid        ,   // 37:37
                     es_dest               ,   // 36:32
                     es_res                    // 31:0
                     };// es forward bus

// mul & div parts
// mul
assign mul_res = $signed({es_alu_src1[31] & es_mult, es_alu_src1}) * $signed({es_alu_src2[31] & es_mult, es_alu_src2});

// div 
assign div_ready = div_divisor_ready & div_dividend_ready;
assign divu_ready = divu_divisor_ready & divu_dividend_ready;
// div_valid
always @(posedge clk)
begin
    if(reset) begin
        div_work <= 1'b0;
    end else if(div_ready && div_valid) begin
        div_work <= 1'b1;
    end else if(div_done) begin
        div_work <= 1'b0;
    end
end
assign div_valid = es_valid && es_div && !div_work && es_data_valid;
// divu_valid
always @(posedge clk)
begin
    if(reset) begin
        divu_work <= 1'b0;
    end else if(divu_ready && divu_valid) begin
        divu_work <= 1'b1;
    end else if(divu_done) begin
        divu_work <= 1'b0;
    end
end
assign divu_valid = es_valid && es_divu && !divu_work && es_data_valid;

mydiv u_mydiv(
      .aclk                   (clk               ),
      .s_axis_divisor_tvalid  (div_valid         ),
      .s_axis_divisor_tready  (div_divisor_ready ),
      .s_axis_divisor_tdata   (es_alu_src2       ),
      .s_axis_dividend_tvalid (div_valid         ),
      .s_axis_dividend_tready (div_dividend_ready),
      .s_axis_dividend_tdata  (es_alu_src1       ),
      .m_axis_dout_tvalid     (div_done          ),
      .m_axis_dout_tdata      (div_res           )
    );
mydivu u_mydivu(
      .aclk                   (clk                ),
      .s_axis_divisor_tvalid  (divu_valid         ),
      .s_axis_divisor_tready  (divu_divisor_ready ),
      .s_axis_divisor_tdata   (es_alu_src2        ),
      .s_axis_dividend_tvalid (divu_valid         ),
      .s_axis_dividend_tready (divu_dividend_ready),
      .s_axis_dividend_tdata  (es_alu_src1        ),
      .m_axis_dout_tvalid     (divu_done          ),
      .m_axis_dout_tdata      (divu_res           )
    );

always @(posedge clk)
begin
    if(reset) begin
        hi <= 32'b0;
        lo <= 32'b0;
    end else if((es_mult || es_multu) && es_data_valid) begin
        hi <= mul_res[63:32];
        lo <= mul_res[31: 0];
    end else if(es_div && div_done && es_data_valid) begin
        lo <= div_res[63:32];
        hi <= div_res[31: 0];
    end else if(es_divu && divu_done && es_data_valid) begin
        lo <= divu_res[63:32];
        hi <= divu_res[31: 0];
    end else if(es_mthi && es_data_valid) begin
        hi <= es_rs_value;
        lo <= lo;
    end else if(es_mtlo && es_data_valid) begin
        hi <= hi;
        lo <= es_rs_value;
    end else begin
        hi <= hi;
        lo <= lo;
    end
end

// exception
assign es_ex     = es_valid && (ds_ex || es_overflow || es_ld_addr_error || es_st_addr_error);
assign es_excode = ({5{es_ex}} & 
                   (ds_ex ? ds_excode
                          : (({5{es_overflow}}      & `EX_OV  ) |
                             ({5{es_ld_addr_error}} & `EX_ADEL) |
                             ({5{es_st_addr_error}} & `EX_ADES)) ));
assign es_badvaddr = {32{es_valid && (ds_ex || es_ld_addr_error || es_st_addr_error)}}
                   & (ds_ex ? ds_badvaddr : es_alu_result);
endmodule
