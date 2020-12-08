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

// TLB module
// write port
wire                       we     ;     // w(rite) e(nable)
wire  [               3:0] w_index;
wire  [              18:0] w_vpn2 ;
wire  [               7:0] w_asid ;
wire                       w_g    ;
wire  [              19:0] w_pfn0 ;
wire  [               2:0] w_c0   ;
wire                       w_d0   ;
wire                       w_v0   ;
wire  [              19:0] w_pfn1 ;
wire  [               2:0] w_c1   ;
wire                       w_d1   ;
wire                       w_v1   ;
// read port
wire [               3:0] r_index;
wire [              18:0] r_vpn2 ;
wire [               7:0] r_asid ;
wire                      r_g    ;
wire [              19:0] r_pfn0 ;
wire [               2:0] r_c0   ;
wire                      r_d0   ;
wire                      r_v0   ;
wire [              19:0] r_pfn1 ;
wire [               2:0] r_c1   ;
wire                      r_d1   ;
wire                      r_v1   ;

tlb u_tlb(
    .clk        (clk        ),

    // search port 0
    .s0_vpn2    (s0_vpn2    ),
    .s0_odd_page(s0_odd_page),
    .s0_asid    (s0_asid    ),
    .s0_found   (s0_found   ),
    .s0_index   (s0_index   ),
    .s0_pfn     (s0_pfn     ),
    .s0_c       (s0_c       ),
    .s0_d       (s0_d       ),
    .s0_v       (s0_v       ),

    // search port 1
    .s1_vpn2    (s1_vpn2    ),
    .s1_odd_page(s1_odd_page),
    .s1_asid    (s1_asid    ),
    .s1_found   (s1_found   ),
    .s1_index   (s1_index   ),
    .s1_pfn     (s1_pfn     ),
    .s1_c       (s1_c       ),
    .s1_d       (s1_d       ),
    .s1_v       (s1_v       ),

    // write port
    .we         (we         ),      // w(rite) e(nable)
    .w_index    (w_index    ),
    .w_vpn2     (w_vpn2     ),
    .w_asid     (w_asid     ),
    .w_g        (w_g        ),
    .w_pfn0     (w_pfn0     ),
    .w_c0       (w_c0       ),
    .w_d0       (w_d0       ),
    .w_v0       (w_v0       ),
    .w_pfn1     (w_pfn1     ),
    .w_c1       (w_c1       ),
    .w_d1       (w_d1       ),
    .w_v1       (w_v1       ),

    // read port
    .r_index    (r_index    ),
    .r_vpn2     (r_vpn2     ),
    .r_asid     (r_asid     ),
    .r_g        (r_g        ),
    .r_pfn0     (r_pfn0     ),
    .r_c0       (r_c0       ),
    .r_d0       (r_d0       ),
    .r_v0       (r_v0       ),
    .r_pfn1     (r_pfn1     ),
    .r_c1       (r_c1       ),
    .r_d1       (r_d1       ),
    .r_v1       (r_v1       )
);

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
    .has_int    (has_int          ),

    .c0_entryhi (c0_entryhi       ),
    .c0_entrylo0(c0_entrylo0      ),
    .c0_entrylo1(c0_entrylo1      ),
    .c0_index   (c0_index         ),
    .tlbp       (tlbp             ),
    .tlbp_found (tlbp_found       ),
    .index      (index            ),
    .tlbr       (tlbr             ),
    .r_vpn2     (r_vpn2           ),
    .r_asid     (r_asid           ),
    .r_g        (r_g              ),
    .r_pfn0     (r_pfn0           ),
    .r_c0       (r_c0             ),
    .r_d0       (r_d0             ),
    .r_v0       (r_v0             ),
    .r_pfn1     (r_pfn1           ),
    .r_c1       (r_c1             ),
    .r_d1       (r_d1             ),
    .r_v1       (r_v1             )
);

endmodule
