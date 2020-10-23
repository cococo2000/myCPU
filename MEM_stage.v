`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    //forward
    output [`MS_FWD_BUS_WD -1  :0] ms_fwd_bus
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire [ 6:0] ms_ld_inst;
wire [ 3:0] ms_rf_we;

assign {ms_ld_inst     ,  //76:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_res_from_mem = (|ms_ld_inst);
assign ms_to_ws_bus = {ms_rf_we       ,  //72:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };


assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
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

assign lb_data      = mem_pos == 2'd0 ? data_sram_rdata [ 7: 0]         :
                      mem_pos == 2'd1 ? data_sram_rdata [15: 8]         :
                      mem_pos == 2'd2 ? data_sram_rdata [23:16]         :
                   /* mem_pos == 2'd3 */data_sram_rdata [31:24];

assign lh_data      = mem_pos == 2'd0 ? data_sram_rdata [15: 0]         :
                                        data_sram_rdata [31:16];

assign lwl_data     = mem_pos == 2'd0 ? {data_sram_rdata[ 7: 0], 24'b0} :
                      mem_pos == 2'd1 ? {data_sram_rdata[15: 0], 16'b0} :
                      mem_pos == 2'd2 ? {data_sram_rdata[23: 0],  8'b0} :
                      data_sram_rdata;

assign lwr_data     = mem_pos == 2'd3 ? {24'b0, data_sram_rdata[31:24]} :
                      mem_pos == 2'd2 ? {16'b0, data_sram_rdata[31:16]} :
                      mem_pos == 2'd1 ? { 8'b0, data_sram_rdata[31: 8]} :
                      data_sram_rdata;
assign mem_result   = inst_lb ? {{24{lb_data[ 7]}}, lb_data}:
                      inst_lbu? { 24'b0           , lb_data}:
                      inst_lh ? {{16{lh_data[15]}}, lh_data}:
                      inst_lhu? { 16'b0           , lh_data}:
                      inst_lwl? lwl_data                    :
                      inst_lwr? lwr_data                    :
                                data_sram_rdata;
assign ms_final_result = ms_res_from_mem ? mem_result   :
                                           ms_alu_result;

// ms forward bus
wire ms_block;
wire ms_block_valid;
assign ms_block = ms_gr_we;
assign ms_block_valid = ms_block && ms_valid;
assign ms_fwd_bus = {ms_rf_we       ,    // 41:38
                     ms_block_valid ,    // 37:37
                     ms_dest        ,    // 36:32
                     ms_final_result     // 31:0
                    };

endmodule
