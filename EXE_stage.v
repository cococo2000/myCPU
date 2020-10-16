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
wire        es_mult       ;
wire        es_multu      ;
wire        es_div        ;
wire        es_divu       ;
wire        es_mfhi       ;
wire        es_mflo       ;
wire        es_mthi       ;
wire        es_mtlo       ;
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
        es_mult        ,  // 144:144
        es_multu       ,  // 143:143
        es_div         ,  // 142:142
        es_divu        ,  // 141:141
        es_mfhi        ,  // 140:140
        es_mflo        ,  // 139:139
        es_mthi        ,  // 138:138
        es_mtlo        ,  // 137:137
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
wire [31:0] es_res        ;

wire        es_res_from_mem;

// mul & div parts
reg  [31:0] hi;
reg  [31:0] lo;
wire [63:0] mult_res;
wire [63:0] multu_res;
wire [63:0] div_res;
wire [63:0] divu_res;
// div
reg  div_valid;
wire div_ready;
wire div_divisor_ready;
wire div_dividend_ready;
wire div_done;
// divu
reg  divu_valid;
wire divu_ready;
wire divu_divisor_ready;
wire divu_dividend_ready;
wire divu_done;

assign es_res_from_mem = es_load_op;
assign es_res = es_mfhi ? hi :
                es_mflo ? lo :
                          es_alu_result;
assign es_to_ms_bus = {es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_res         ,  //63:32
                       es_pc             //31:0
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
                     es_res                    // 31:0
                     };// es forward bus

// mul & div parts
// mul
assign mult_res  = $signed(es_alu_src1) * $signed(es_alu_src2);
assign multu_res = es_alu_src1 * es_alu_src2;
// div 
assign div_ready = div_divisor_ready & div_dividend_ready;
assign divu_ready = divu_divisor_ready & divu_dividend_ready;
// div_ready
always @(posedge clk)
begin
    if(reset) begin
        div_valid <= 1'b0;
    end else if(div_ready && div_valid) begin
        div_valid <= 1'b0;
    end else if (ds_to_es_valid && es_allowin) begin
        div_valid <= ds_to_es_bus[142:142];
    end
end
// divu_ready
always @(posedge clk)
begin
    if(reset) begin
        divu_valid <= 1'b0;
    end else if(divu_ready && divu_valid) begin
        divu_valid <= 1'b0;
    end else if(ds_to_es_valid && es_allowin) begin
        divu_valid <= ds_to_es_bus[141:141];
    end
end

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
    end else if(es_mult) begin
        hi <= mult_res[63:32];
        lo <= mult_res[31: 0];
    end else if(es_multu) begin
        hi <= multu_res[63:32];
        lo <= multu_res[31: 0];
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
