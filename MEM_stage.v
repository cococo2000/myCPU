`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    // allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    // from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    // from data-sram
    // input  [31                 :0] data_sram_rdata,
    // sram like interface
    input                          data_sram_data_ok,
    input  [31                 :0] data_sram_rdata,
    // forward
    output [`MS_FWD_BUS_WD -1  :0] ms_fwd_bus    ,
    output                         ms_mt_entryhi ,
    output                         ms_flush      ,
    input                          flush
);

reg         ms_valid;
wire        ms_ready_go;
reg         cancel;
reg         data_sram_rdata_r_valid;
reg  [31:0] data_sram_rdata_r;
wire [31:0] true_data_sram_rdata;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire        ms_store_op;
wire [ 6:0] ms_ld_inst;
wire [ 3:0] ms_rf_we;
// exception
wire [10:0] c0_bus;
wire        ms_bd;
wire        es_ex;
wire [ 4:0] es_excode;
wire [31:0] ms_badvaddr;
wire [31:0] es_badvaddr;
// TLB
wire        ms_tlbwi;
wire        ms_tlbr;
assign {
        ms_tlbwi       ,  // 130:130
        ms_tlbr        ,  // 129:129
        ms_store_op    ,  // 128:128
        es_badvaddr    ,  // 127:96
        c0_bus         ,  // 95:85
        ms_bd          ,  // 84:84
        es_ex          ,  // 83:83
        es_excode      ,  // 82:78
        ms_ld_inst     ,  // 77:71
        ms_res_from_mem,  // 70:70
        ms_gr_we       ,  // 69:69
        ms_dest        ,  // 68:64
        ms_alu_result  ,  // 63:32
        ms_pc             // 31:0
       } = es_to_ms_bus_r;
assign ms_badvaddr = es_badvaddr;
wire [31:0] mem_result;
wire [31:0] ms_final_result;
wire        ms_ex;
wire [ 4:0] ms_excode;
wire        ms_eret;
wire        ms_mtc0;
wire        ms_mfc0;
wire [ 7:0] c0_raddr;
assign {ms_eret,   // 10:10
        ms_mtc0,   // 9:9
        ms_mfc0,   // 8:8
        c0_raddr   // 7:0
       } = c0_bus && {11{ms_valid}};
assign ms_mt_entryhi = ms_mtc0 && (c0_raddr[7:3] == `CR_ENTRYHI) && ms_valid;
assign ms_flush = ms_valid && (ms_eret || ms_ex);
assign ms_to_ws_bus = {
                       ms_tlbwi       ,  // 124:124
                       ms_tlbr        ,  // 123:123
                       ms_badvaddr    ,  // 122:91
                       c0_bus         ,  // 90:80
                       ms_bd          ,  // 79:79
                       ms_ex          ,  // 78:78
                       ms_excode      ,  // 77:73
                       ms_rf_we       ,  // 72:69
                       ms_dest        ,  // 68:64
                       ms_final_result,  // 63:32
                       ms_pc             // 31:0
                      };

assign ms_ready_go    = !(ms_store_op || ms_res_from_mem) || data_sram_rdata_r_valid || data_sram_data_ok && !cancel || ms_ex;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go && !flush;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (flush) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end

wire [ 1:0] mem_pos ;
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
       } = ms_ld_inst;
assign mem_pos  = ms_alu_result[1:0];
assign ms_rf_we = {4{ms_valid}} & (
                   inst_lwl ? {1'b1           , mem_pos != 2'd0, mem_pos[1]     , mem_pos == 2'd3} :
                   inst_lwr ? {mem_pos == 2'd0, ~mem_pos[1]    , mem_pos != 2'd3, 1'b1           } :
                // (inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu) ? {                   4'hf} :
                              {4{ms_gr_we}});

wire [ 7:0] lb_data;
wire [15:0] lh_data;
wire [31:0] lwl_data;
wire [31:0] lwr_data;

assign lb_data      = mem_pos == 2'd0 ? true_data_sram_rdata[ 7: 0]         :
                      mem_pos == 2'd1 ? true_data_sram_rdata[15: 8]         :
                      mem_pos == 2'd2 ? true_data_sram_rdata[23:16]         :
                   /* mem_pos == 2'd3 */true_data_sram_rdata[31:24];

assign lh_data      = mem_pos == 2'd0 ? true_data_sram_rdata[15: 0]         :
                                        true_data_sram_rdata[31:16];

assign lwl_data     = mem_pos == 2'd0 ? {true_data_sram_rdata[ 7: 0], 24'b0} :
                      mem_pos == 2'd1 ? {true_data_sram_rdata[15: 0], 16'b0} :
                      mem_pos == 2'd2 ? {true_data_sram_rdata[23: 0],  8'b0} :
                                         true_data_sram_rdata;

assign lwr_data     = mem_pos == 2'd3 ? {24'b0, true_data_sram_rdata[31:24]} :
                      mem_pos == 2'd2 ? {16'b0, true_data_sram_rdata[31:16]} :
                      mem_pos == 2'd1 ? { 8'b0, true_data_sram_rdata[31: 8]} :
                                        true_data_sram_rdata;
assign mem_result   = inst_lb ? {{24{lb_data[ 7]}}, lb_data}:
                      inst_lbu? { 24'b0           , lb_data}:
                      inst_lh ? {{16{lh_data[15]}}, lh_data}:
                      inst_lhu? { 16'b0           , lh_data}:
                      inst_lwl? lwl_data                    :
                      inst_lwr? lwr_data                    :
                                true_data_sram_rdata;
assign ms_final_result = ms_res_from_mem ? mem_result   :
                                           ms_alu_result;

always@(posedge clk) begin
    if (reset) begin
        cancel <= 1'b0;
    end
    else if (data_sram_data_ok) begin
        cancel <= 1'b0;
    end
    else if (flush) begin
        if (es_to_ms_valid || ms_allowin == 1'b0 && ms_ready_go == 1'b0) begin
            cancel <= 1'b1;
        end
    end
end

always@(posedge clk)begin
    if(reset)begin
        data_sram_rdata_r_valid <= 1'b0;
    end
    else if(flush) begin
        data_sram_rdata_r_valid <= 1'b0;
    end
    else if(ms_to_ws_valid && ws_allowin)begin
        data_sram_rdata_r_valid <= 1'b0;
    end
    else if(ms_valid && data_sram_data_ok)begin
        data_sram_rdata_r_valid <= 1'b1;
    end
end

always @(posedge clk) begin
    if (reset) begin
        data_sram_rdata_r <= 32'b0;
    end
    else if (data_sram_data_ok)begin
        data_sram_rdata_r <= data_sram_rdata;
    end
end

assign true_data_sram_rdata = data_sram_rdata_r_valid ? data_sram_rdata_r : data_sram_rdata;

// ms forward bus
wire ms_block;
wire ms_block_valid;
assign ms_block = ms_gr_we;
assign ms_block_valid = ms_block && ms_valid;
assign ms_fwd_bus = {ms_valid && ms_mfc0        ,   // 43:43
                     ms_valid && ms_res_from_mem,   // 42:42
                     ms_rf_we                   ,   // 41:38
                     ms_block_valid             ,   // 37:37
                     ms_dest                    ,   // 36:32
                     ms_final_result                // 31:0
                    };

// exception
assign ms_ex = ms_valid && es_ex;
assign ms_excode = {5{ms_ex}} & es_excode;
endmodule
