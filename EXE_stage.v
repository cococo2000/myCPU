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
wire [11:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm;
wire        es_src2_is_uimm;
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire [ 4:0] es_st_inst    ;
wire [ 6:0] es_ld_inst    ;
wire [ 7:0] es_md_inst    ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;

assign {es_ld_inst     , // 155:149
        es_st_inst     , // 148:144
        es_md_inst     , // 143:136
        es_alu_op      , // 135:124
        es_load_op     , // 123:123
        es_src1_is_sa  , // 122:122
        es_src1_is_pc  , // 121:121
        es_src2_is_imm , // 120:120
        es_src2_is_uimm, // 119:119
        es_src2_is_8   , // 118:118
        es_gr_we       , // 117:117
        es_dest        , // 116:112
        es_imm         , // 111:96
        es_rs_value    , // 95 :64
        es_rt_value    , // 63 :32
        es_pc            // 31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_res        ;
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

assign es_res = es_mfhi ? hi :
                es_mflo ? lo :
                          es_alu_result;
assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_ld_inst     ,  // 77:71
                       es_res_from_mem,  // 70:70
                       es_gr_we       ,  // 69:69
                       es_dest        ,  // 68:64
                       es_res         ,  // 63:32
                       es_pc             // 31:0
                      };

assign es_ready_go    = !(es_div || es_divu) || (es_div && div_done) || (es_divu && divu_done);
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

assign data_sram_en    = 1'b1;
assign data_sram_wen   ={4{es_valid}} & ( 
                        inst_sw ?  4'hf                                                                :
                        inst_sh ? {                 {2{mem_pos[1]}},                 {2{~mem_pos[1]}}} :
                        inst_sb ? {mem_pos == 2'd3, mem_pos == 2'd2, mem_pos == 2'd1, mem_pos == 2'd0} :
                        inst_swl? {mem_pos == 2'd3, mem_pos[1]     , mem_pos!=2'd0  , 1'b1           } :
                        inst_swr? {1'b1           , mem_pos != 2'd3, !mem_pos[1]    , mem_pos == 2'd0} :
                                   4'b0);
assign data_sram_addr  = {es_alu_result[31: 2], 2'b0};
assign data_sram_wdata = st_data;

// es forward bus
wire es_block;
wire es_block_valid;
assign es_block = es_gr_we;
assign es_block_valid  = es_block && es_valid;
assign es_fwd_bus = {es_load_op && es_valid,   // 38:38
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
assign div_valid = es_valid && es_div && !div_work;
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
assign divu_valid = es_valid && es_divu && !divu_work;

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
    end else if(es_mult || es_multu) begin
        hi <= mul_res[63:32];
        lo <= mul_res[31: 0];
    end else if(es_div && div_done) begin
        lo <= div_res[63:32];
        hi <= div_res[31: 0];
    end else if(es_divu && divu_done) begin
        lo <= divu_res[63:32];
        hi <= divu_res[31: 0];
    end else if(es_mthi) begin
        hi <= es_rs_value;
        lo <= lo;
    end else if(es_mtlo) begin
        hi <= hi;
        lo <= es_rs_value;
    end else begin
        hi <= hi;
        lo <= lo;
    end
end
endmodule
