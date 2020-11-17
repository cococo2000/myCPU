`include "mycpu.h"
module mycpu_top(
    input  [5 :0] int    ,  // high active
    input         aclk   ,
    input         aresetn,  // low active
    // axi interface
    // ar: acquire reading channels
    output [3 :0] arid   ,
    output [31:0] araddr ,
    output [7 :0] arlen  ,
    output [2 :0] arsize ,
    output [1 :0] arburst,
    output [1 :0] arlock ,
    output [3 :0] arcache,
    output [2 :0] arprot ,
    output        arvalid,
    input         arready,
    // r: reading response channels
    input  [3 :0] rid    ,
    input  [31:0] rdata  ,
    input  [1 :0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output        rready ,
    // aw: acquire writing channels
    output [3 :0] awid   ,
    output [31:0] awaddr ,
    output [7 :0] awlen  ,
    output [2 :0] awsize ,
    output [1 :0] awburst,
    output [1 :0] awlock ,
    output [3 :0] awcache,
    output [2 :0] awprot ,
    output        awvalid,
    input         awready,
    // w: write data channels
    output [3 :0] wid    ,
    output [31:0] wdata  ,
    output [3 :0] wstrb  ,
    output        wlast  ,
    output        wvalid ,
    input         wready ,
    // b: writing response channels
    input  [3 :0] bid    ,
    input  [1 :0] bresp  ,
    input         bvalid ,
    output        bready ,

    // input         clk,
    // input         resetn,

    // inst sram interface
    // output        inst_sram_en,
    // output [ 3:0] inst_sram_wen,
    // output [31:0] inst_sram_addr,
    // output [31:0] inst_sram_wdata,
    // input  [31:0] inst_sram_rdata,
    // inst sram like interface
    // output        inst_sram_req,
    // output        inst_sram_wr,
    // output [ 1:0] inst_sram_size,
    // output [ 3:0] inst_sram_wstrb,
    // output [31:0] inst_sram_addr,
    // output [31:0] inst_sram_wdata,
    // input         inst_sram_addr_ok,
    // input         inst_sram_data_ok,
    // input  [31:0] inst_sram_rdata,

    // data sram interface
    // output        data_sram_en,
    // output [ 3:0] data_sram_wen,
    // output [31:0] data_sram_addr,
    // output [31:0] data_sram_wdata,
    // input  [31:0] data_sram_rdata,
    // data sram like interface
    // output        data_sram_req,
    // output        data_sram_wr,
    // output [ 1:0] data_sram_size,
    // output [ 3:0] data_sram_wstrb,
    // output [31:0] data_sram_addr,
    // output [31:0] data_sram_wdata,
    // input         data_sram_addr_ok,
    // input         data_sram_data_ok,
    // input  [31:0] data_sram_rdata,

    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge aclk) reset <= ~aresetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus      ;

// forward part
wire [`ES_FWD_BUS_WD   -1:0] es_fwd_bus;
wire [`MS_FWD_BUS_WD   -1:0] ms_fwd_bus;

// exception
wire [31:0] cp0_epc      ;
wire        ws_eret      ;
wire        ws_ex        ;
wire        ms_flush     ;
wire        flush        ;
wire        es_ex        ;
wire        es_data_valid;
wire        has_int      ;
assign flush = ws_ex || ws_eret;
assign es_data_valid = !(flush || ms_flush || es_ex);

// inst sram like interface
wire        inst_sram_req    ;
wire        inst_sram_wr     ;
wire [ 1:0] inst_sram_size   ;
wire [31:0] inst_sram_addr   ;
wire [31:0] inst_sram_wdata  ;
wire [31:0] inst_sram_rdata  ;
wire        inst_sram_addr_ok;
wire        inst_sram_data_ok;
// data sram like interface
wire        data_sram_req    ;
wire        data_sram_wr     ;
wire [ 1:0] data_sram_size   ;
wire [31:0] data_sram_addr   ;
wire [31:0] data_sram_wdata  ;
wire [31:0] data_sram_rdata  ;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;

// IF stage
if_stage if_stage(
    .clk              (clk              ),
    .reset            (reset            ),
    // allowin
    .ds_allowin       (ds_allowin       ),
    // brbus
    .br_bus           (br_bus           ),
    // outputs
    .fs_to_ds_valid   (fs_to_ds_valid   ),
    .fs_to_ds_bus     (fs_to_ds_bus     ),
    // inst sram interface
    // .inst_sram_en   (inst_sram_en   ),
    // .inst_sram_wen  (inst_sram_wen  ),
    // .inst_sram_addr (inst_sram_addr ),
    // .inst_sram_wdata(inst_sram_wdata),
    // .inst_sram_rdata(inst_sram_rdata),
    // inst sram like interface
    .inst_sram_req    (inst_sram_req    ),
    .inst_sram_wr     (inst_sram_wr     ),
    .inst_sram_size   (inst_sram_size   ),
    .inst_sram_wstrb  (inst_sram_wstrb  ),
    .inst_sram_addr   (inst_sram_addr   ),
    .inst_sram_wdata  (inst_sram_wdata  ),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata  (inst_sram_rdata  ),

    .cp0_epc          (cp0_epc          ),
    .ws_eret          (ws_eret          ),
    .ws_ex            (ws_ex            )
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    // allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    // from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    // to fs
    .br_bus         (br_bus         ),
    // to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    // forward_bus
    .es_fwd_bus     (es_fwd_bus     ),
    .ms_fwd_bus     (ms_fwd_bus     ),
    .flush          (flush          ),
    .has_int        (has_int        )
);
// EXE stage
exe_stage exe_stage(
    .clk              (clk              ),
    .reset            (reset            ),
    // allowin
    .ms_allowin       (ms_allowin       ),
    .es_allowin       (es_allowin       ),
    // from ds
    .ds_to_es_valid   (ds_to_es_valid   ),
    .ds_to_es_bus     (ds_to_es_bus     ),
    // to ms
    .es_to_ms_valid   (es_to_ms_valid   ),
    .es_to_ms_bus     (es_to_ms_bus     ),
    // data sram interface
    // .data_sram_en   (data_sram_en   ),
    // .data_sram_wen  (data_sram_wen  ),
    // .data_sram_addr (data_sram_addr ),
    // .data_sram_wdata(data_sram_wdata),
    // data sram like interface
    .data_sram_req    (data_sram_req    ),
    .data_sram_wr     (data_sram_wr     ),
    .data_sram_size   (data_sram_size   ),
    .data_sram_wstrb  (data_sram_wstrb  ),
    .data_sram_addr   (data_sram_addr   ),
    .data_sram_wdata  (data_sram_wdata  ),
    .data_sram_addr_ok(data_sram_addr_ok),
    // forward_bus
    .es_fwd_bus       (es_fwd_bus       ),
    .es_data_valid    (es_data_valid    ),
    .es_ex            (es_ex            ),
    .flush            (flush            )
);
// MEM stage
mem_stage mem_stage(
    .clk              (clk              ),
    .reset            (reset            ),
    // allowin
    .ws_allowin       (ws_allowin       ),
    .ms_allowin       (ms_allowin       ),
    // from es
    .es_to_ms_valid   (es_to_ms_valid   ),
    .es_to_ms_bus     (es_to_ms_bus     ),
    // to ws
    .ms_to_ws_valid   (ms_to_ws_valid   ),
    .ms_to_ws_bus     (ms_to_ws_bus     ),
    // from data-sram
    // .data_sram_rdata(data_sram_rdata),
    // data sram like interface
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata  (data_sram_rdata  ),
    // forward_bus
    .ms_fwd_bus       (ms_fwd_bus       ),
    .ms_flush         (ms_flush         ),
    .flush            (flush            )
);
// WB stage
wb_stage wb_stage(
    .clk              (clk              ),
    .reset            (reset            ),
    // allowin
    .ws_allowin       (ws_allowin       ),
    // from ms
    .ms_to_ws_valid   (ms_to_ws_valid   ),
    .ms_to_ws_bus     (ms_to_ws_bus     ),
    // to rf: for write back and forward bus (to ds)
    .ws_to_rf_bus     (ws_to_rf_bus     ),
    // trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),

    .cp0_epc          (cp0_epc          ),
    .ws_eret          (ws_eret          ),
    .ws_ex            (ws_ex            ),
    .has_int          (has_int          )
);

cpu_axi_interface cpu_axi_interface(
    .clk              (aclk             ),
    .resetn           (aresetn          ),

    // inst sram like interface
    .inst_sram_req    (inst_sram_req    ),
    .inst_sram_wr     (inst_sram_wen    ),
    .inst_sram_size   (inst_sram_size   ),
    .inst_sram_addr   (inst_sram_addr   ),
    .inst_sram_wdata  (inst_sram_wdata  ),
    .inst_sram_rdata  (inst_sram_rdata  ),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),

    // data sram like interface
    .data_sram_req    (data_sram_req    ),
    .data_sram_wr     (data_sram_wen    ),
    .data_sram_size   (data_sram_size   ),
    .data_sram_addr   (data_sram_addr   ),
    .data_sram_wdata  (data_sram_wdata  ),
    .data_sram_rdata  (data_sram_rdata  ),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_data_ok(data_sram_data_ok),

    // axi interface
    // ar: acquire reading channels
    .arid             (arid             ),
    .araddr           (araddr           ),
    .arlen            (arlen            ),
    .arsize           (arsize           ),
    .arburst          (arburst          ),
    .arlock           (arlock           ),
    .arcache          (arcache          ),
    .arprot           (arprot           ),
    .arvalid          (arvalid          ),
    .arready          (arready          ),
    // r: reading response channels
    .rid              (rid              ),
    .rdata            (rdata            ),
    .rresp            (rresp            ),
    .rlast            (rlast            ),
    .rvalid           (rvalid           ),
    .rready           (rready           ),
    // aw: acquire writing channels
    .awid             (awid            ),
    .awaddr           (awaddr          ),
    .awlen            (awlen           ),
    .awsize           (awsize          ),
    .awburst          (awburst         ),
    .awlock           (awlock          ),
    .awcache          (awcache         ),
    .awprot           (awprot          ),
    .awvalid          (awvalid         ),
    .awready          (awready         ),
    // w: write data channels
    .wid              (wid             ),
    .wdata            (wdata           ),
    .wstrb            (wstrb           ),
    .wlast            (wlast           ),
    .wvalid           (wvalid          ),
    .wready           (wready          ),
    // b: writing response channels
    .bid              (bid             ),
    .bresp            (bresp           ),
    .bvalid           (bvalid          ),
    .bready           (bready          )
);

endmodule
