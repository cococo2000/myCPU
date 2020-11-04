`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    // allowin
    output                          ws_allowin    ,
    // from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    // to rf: for write back and forward bus (to ds)
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    // trace debug interface
    output [31:0] debug_wb_pc      ,
    output [ 3:0] debug_wb_rf_wen  ,
    output [ 4:0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata,
    output [31:0] cp0_epc,
    output        ws_eret,
    output        ws_ex,
    output has_int
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
// wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
wire [3 :0] ws_rf_we;
wire [3 :0] rf_we;
// exception
wire [10:0] c0_bus;
// wire        ws_eret; declare in output
wire        ws_mtc0;
wire        ws_mfc0;
wire [ 7:0] c0_raddr;
wire        ws_bd;
wire        ms_ex;
wire [ 4:0] ms_excode;
wire [31:0] ms_badvaddr;
wire [31: 0] wb_badvaddr;
assign {
        ms_badvaddr    , // 122:91
        c0_bus         ,  // 90:80
        ws_bd          ,  // 79:79
        ms_ex          ,  // 78:78
        ms_excode      ,  // 77:73
        ws_rf_we       ,  // 72:69
        ws_dest        ,  // 68:64
        ws_final_result,  // 63:32
        ws_pc             // 31:0
       } = ms_to_ws_bus_r;
assign wb_badvaddr = ms_badvaddr;
assign {ws_eret,   // 10:10
        ws_mtc0,   // 9:9
        ws_mfc0,   // 8:8
        c0_raddr  // 7:0
       } = c0_bus & {11{ws_valid}};
wire [31:0] cp0_rdata;
wire        eret_flush;
assign eret_flush = ws_valid && ws_eret;

wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //40:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

// exception
// wire        ws_ex; declare in output
wire [ 4:0] ws_excode;
assign ws_ex = ws_valid && ms_ex;
assign ws_excode = {5{ws_ex}} & ms_excode;


assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_ex || eret_flush) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = {4{ws_valid & ~ws_ex}} & ws_rf_we;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_mfc0 ? cp0_rdata : ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = rf_we;
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;

// int signals
wire [5:0] ext_int_in;
assign ext_int_in = 6'b0;
// cp0_regfile
cp0_regfile u_cp0_regfile(
    .clk        (clk              ),
    .reset      (reset            ),
    .mtc0_we    (ws_mtc0 && !ws_ex),
    .c0_raddr   (c0_raddr         ),
    .c0_wdata   (ws_final_result  ),
    .wb_bd      (ws_bd            ),
    .wb_ex      (ws_ex            ),
    .wb_excode  (ws_excode        ),
    .eret_flush (eret_flush       ),
    .wb_badvaddr(wb_badvaddr      ),
    .wb_pc      (ws_pc            ),
    .rdata      (cp0_rdata        ),
    .c0_epc     (cp0_epc          ),
    .ext_int_in (ext_int_in       ),
    .has_int    (has_int          )
);

endmodule
