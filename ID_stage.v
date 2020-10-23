`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //foward_recv
    input [`ES_FWD_BUS_WD    -1:0] es_fwd_bus    ,
    input [`MS_FWD_BUS_WD    -1:0] ms_fwd_bus
);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

// Branch and Jump bus: br_bus
wire        rs_eq_rt;
wire        rs_ltz;
wire        rs_gtz;
wire        br_stall;
wire        br_taken;
wire [31:0] br_target;

wire [11:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_uimm;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;
// lab6
wire        inst_add;
wire        inst_addi;
wire        inst_sub;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sllv;
wire        inst_srav;
wire        inst_srlv;
wire        inst_mult;
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
//lab7
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_j;
wire        inst_bltzal;
wire        inst_bgezal;
wire        inst_jalr;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_sb;
wire        isnt_sh;
wire        inst_swl;
wire        inst_swr;

// write reg dest
wire        dst_is_r31;  
wire        dst_is_rt;   

// regfiles
wire [ 3:0] rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

// block & forward parts
wire        blocked;
// es forward bus
wire        es_load;
wire        es_block_valid;
wire [31:0] es_res;
wire [ 4:0] es_dest;
// ms forward bus
wire        ms_block_valid;
wire [ 3:0] ms_rf_we;
wire [31:0] ms_res;
wire [ 4:0] ms_dest;
// ws_to_rf_bus
wire        rs_valid;
wire        rt_valid;
// judge regfile waddr eq?
wire        rs_eq_es_dest ;
wire        rs_eq_ms_dest ;
wire        rs_eq_rf_waddr;
wire        rt_eq_es_dest ;
wire        rt_eq_ms_dest ;
wire        rt_eq_rf_waddr;
// forward valid
wire        rs_es_fwd_valid;
wire        rs_ms_fwd_valid;
wire        rs_ws_fwd_valid;
wire        rt_es_fwd_valid;
wire        rt_ms_fwd_valid;
wire        rt_ws_fwd_valid;
// forward data
wire [31:0] ms_wdata_rs;
wire [31:0] ms_wdata_rt;
wire [31:0] rf_wdata_rs;    // ws
wire [31:0] rf_wdata_rt;    // ws
// inst
wire [ 4:0] st_inst;    // store instruction
wire [ 6:0] ld_inst;    // load instruction
wire [ 7:0] md_inst;    // mul and div instruction


assign ds_to_es_bus = {ld_inst     , // 155:149
                       st_inst     , // 148:144
                       md_inst     , // 143:136
                       alu_op      , // 135:124
                       load_op     , // 123:123
                       src1_is_sa  , // 122:122
                       src1_is_pc  , // 121:121
                       src2_is_imm , // 120:120
                       src2_is_uimm, // 119:119
                       src2_is_8   , // 118:118
                       gr_we       , // 117:117
                       dest        , // 116:112
                       imm         , // 111:96 
                       rs_value    , // 95 :64 
                       rt_value    , // 63 :32 
                       ds_pc         // 31 :0  
                      };

assign ds_ready_go    = !blocked;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid =  ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
// lab6
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & rd_d[5'h00] & sa_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & rd_d[5'h00] & sa_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & rd_d[5'h00] & sa_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
//lab7
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_j      = op_d[6'h02];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_jalr   = op_d[6'h00] & func_d[5'h09] & rt_d[5'h00] & sa_d[5'h00];
assign inst_lb     = op_d[6'h20];
assign inst_lbu    = op_d[6'h24];
assign inst_lh     = op_d[6'h21];
assign inst_lhu    = op_d[6'h25];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];

assign alu_op[ 0] = inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal | inst_add | inst_addi |
                    inst_lb   | inst_lbu   | inst_lh | inst_lhu| inst_lwl | inst_lwr | inst_sb   |
                    inst_sh   | inst_swl   | inst_swr| inst_bltzal| inst_bgezal|inst_jalr;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or   | inst_ori; 
assign alu_op[ 7] = inst_xor  | inst_xori;
assign alu_op[ 8] = inst_sll  | inst_sllv;
assign alu_op[ 9] = inst_srl  | inst_srlv;
assign alu_op[10] = inst_sra  | inst_srav;
assign alu_op[11] = inst_lui;

assign load_op      = inst_lw    | inst_lb   | inst_lbu     | inst_lh    | 
                      inst_lhu   | inst_lwl  | inst_lwr;

assign src1_is_sa   = inst_sll   | inst_srl  | inst_sra;
assign src1_is_pc   = inst_jal   | inst_jalr | inst_bltzal  | inst_bgezal;
assign src2_is_imm  = inst_addiu | inst_addi | inst_slti    | inst_sltiu |
                      inst_lui   | inst_lw   | inst_lh      | inst_lhu   |
                      inst_lb    | inst_lbu  | inst_lwl     | inst_lwr   |
                      inst_sw    | inst_sh   |inst_sb       | inst_swl   | 
                      inst_swr;
assign src2_is_uimm = inst_andi  | inst_ori  | inst_xori;
assign src2_is_8    = inst_jal   | inst_jalr | inst_bltzal  | inst_bgezal;
assign res_from_mem = inst_lw;
assign dst_is_r31   = inst_jal   | inst_jalr | inst_bltzal  | inst_bgezal;
assign dst_is_rt    = inst_addiu | inst_addi | inst_slti    | inst_sltiu |
                      inst_andi  | inst_ori  | inst_xori    |
                      inst_lui   | inst_lw   | inst_lh      | inst_lhu   |
                      inst_lb    | inst_lbu  | inst_lwl     | inst_lwr;
assign gr_we        = ~inst_sw   & ~inst_beq  & ~inst_bne  & ~inst_jr    &
                      ~inst_mthi & ~inst_mtlo & ~inst_mult & ~inst_multu &
                      ~inst_div  & ~inst_divu & ~inst_bgez & ~inst_bgtz  &
                      ~inst_blez & ~inst_bltz & ~inst_j    & ~inst_sb    &
                      ~inst_sh   & ~inst_swl  & ~inst_swr;

assign ld_inst      = { inst_lw     ,
                        inst_lb     ,
                        inst_lbu    ,
                        inst_lh     ,
                        inst_lhu    ,
                        inst_lwl    ,
                        inst_lwr
                      };

assign st_inst      = { inst_sw     ,
                        inst_sh     ,
                        inst_sb     ,
                        inst_swl    ,
                        inst_swr
                       };

assign md_inst      = { inst_mult   ,
                        inst_multu  ,
                        inst_div    ,
                        inst_divu   ,
                        inst_mfhi   ,
                        inst_mflo   ,
                        inst_mthi   ,
                        inst_mtlo
                      };
assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    :
                                   rd;

// block & forward parts
assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

// es forward bus
assign {es_load       , // 38:38
        es_block_valid, // 37:37
        es_dest       , // 36:32
        es_res          // 31:0
       } = es_fwd_bus;
// ms forward bus
assign {ms_rf_we      , // 41:38
        ms_block_valid, // 37:37
        ms_dest       , // 36:32
        ms_res          // 31:0
       } = ms_fwd_bus;
// ws_to_rf_bus
assign {rf_we         , // 40:37
        rf_waddr      , // 36:32
        rf_wdata        // 31:0
       } = ws_to_rf_bus;

assign rs_valid = inst_addu || inst_subu || inst_slt  ||
                  inst_sltu || inst_and  || inst_or   ||
                  inst_xor  || inst_nor  || inst_addiu||
                  inst_lw   || inst_sw   || inst_beq  ||
                  inst_bne  || inst_jr   || inst_add  ||
                  inst_addi || inst_sub  || inst_slti ||
                  inst_sltiu|| inst_andi || inst_ori  ||
                  inst_xori || inst_sllv || inst_srav ||
                  inst_srlv || inst_mult || inst_multu||
                  inst_div  || inst_divu || inst_mthi ||
                  inst_mtlo || inst_bgez || inst_bgtz ||
                  inst_blez || inst_bltz || inst_jalr ||
                  inst_bltzal||inst_bgezal|| inst_lb  ||
                  inst_lbu  || inst_lh   || inst_lhu  ||
                  inst_lwl  || inst_lwr  || inst_sb   ||
                  inst_sh   || inst_swl  || inst_swr;

assign rt_valid = inst_addu || inst_subu || inst_slt  ||
                  inst_sltu || inst_and  || inst_or   ||
                  inst_xor  || inst_nor  || inst_sll  ||
                  inst_srl  || inst_sra  || inst_sw   ||
                  inst_beq  || inst_bne  || inst_add  ||
                  inst_sub  || inst_sllv || inst_srav ||
                  inst_srlv || inst_mult || inst_multu||
                  inst_div  || inst_divu || inst_sb   ||
                  inst_sh   || inst_swl  || inst_swr;

assign rs_eq_es_dest = es_block_valid && (rs == es_dest ) && rs_valid && rs && es_dest;
assign rs_eq_ms_dest = ms_block_valid && (rs == ms_dest ) && rs_valid && rs && ms_dest;
assign rs_eq_rf_waddr= rf_we          && (rs == rf_waddr) && rs_valid && rs && rf_waddr;
assign rt_eq_es_dest = es_block_valid && (rt == es_dest ) && rt_valid && rt && es_dest;
assign rt_eq_ms_dest = ms_block_valid && (rt == ms_dest ) && rt_valid && rt && ms_dest;
assign rt_eq_rf_waddr= rf_we          && (rt == rf_waddr) && rt_valid && rt && rf_waddr;

assign rs_es_fwd_valid = rs_eq_es_dest && !es_load;
assign rs_ms_fwd_valid = rs_eq_ms_dest;
assign rs_ws_fwd_valid = rs_eq_rf_waddr;
assign rt_es_fwd_valid = rt_eq_es_dest && !es_load;
assign rt_ms_fwd_valid = rt_eq_ms_dest;
assign rt_ws_fwd_valid = rt_eq_rf_waddr;

assign blocked = es_load && (rs_eq_es_dest || rt_eq_es_dest);

assign ms_wdata_rs = {{ms_rf_we[3] ?   ms_res[31:24] : rf_rdata1[31:24]},
                      {ms_rf_we[2] ?   ms_res[23:16] : rf_rdata1[23:16]},
                      {ms_rf_we[1] ?   ms_res[15: 8] : rf_rdata1[15: 8]},
                      {ms_rf_we[0] ?   ms_res[ 7: 0] : rf_rdata1[ 7: 0]}};
assign ms_wdata_rt = {{ms_rf_we[3] ?   ms_res[31:24] : rf_rdata2[31:24]},
                      {ms_rf_we[2] ?   ms_res[23:16] : rf_rdata2[23:16]},
                      {ms_rf_we[1] ?   ms_res[15: 8] : rf_rdata2[15: 8]},
                      {ms_rf_we[0] ?   ms_res[ 7: 0] : rf_rdata2[ 7: 0]}};
assign rf_wdata_rs = {{   rf_we[3] ? rf_wdata[31:24] : rf_rdata1[31:24]},
                      {   rf_we[2] ? rf_wdata[23:16] : rf_rdata1[23:16]},
                      {   rf_we[1] ? rf_wdata[15: 8] : rf_rdata1[15: 8]},
                      {   rf_we[0] ? rf_wdata[ 7: 0] : rf_rdata1[ 7: 0]}};
assign rf_wdata_rt = {{   rf_we[3] ? rf_wdata[31:24] : rf_rdata2[31:24]},
                      {   rf_we[2] ? rf_wdata[23:16] : rf_rdata2[23:16]},
                      {   rf_we[1] ? rf_wdata[15: 8] : rf_rdata2[15: 8]},
                      {   rf_we[0] ? rf_wdata[ 7: 0] : rf_rdata2[ 7: 0]}};

assign rs_value = rs_es_fwd_valid ? es_res      :
                  rs_ms_fwd_valid ? ms_wdata_rs :
                  rs_ws_fwd_valid ? rf_wdata_rs :
                                    rf_rdata1   ;

assign rt_value = rt_es_fwd_valid ? es_res      :
                  rt_ms_fwd_valid ? ms_wdata_rt :
                  rt_ws_fwd_valid ? rf_wdata_rt :
                                    rf_rdata2   ;

// Branch and Jump parts
assign rs_eq_rt = (rs_value == rt_value);
assign rs_ltz   = rs_value[31];
assign rs_gtz   = !rs_value[31] & (|rs_value);
assign br_stall = blocked && ds_valid && (inst_beq || inst_bne || inst_jr);
assign br_taken = (   inst_beq                  &&  rs_eq_rt
                   || inst_bne                  && !rs_eq_rt
                   || (inst_bltz | inst_bltzal) &&  rs_ltz
                   || (inst_bgez | inst_bgezal) && !rs_ltz
                   || inst_bgtz                 &&  rs_gtz
                   || inst_blez                 && !rs_gtz
                   || inst_jal
                   || inst_jalr
                   || inst_jr
                   || inst_j
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne || inst_bltz || 
                    inst_bgez|| inst_bgtz|| inst_blez ||
                    inst_bltzal || inst_bgezal) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr  || inst_jalr)? rs_value :
                   (inst_jal || inst_j)   ? {fs_pc[31:28], jidx[25:0], 2'b0} : 32'b0;
assign br_bus    = {br_stall, br_taken, br_target};

endmodule
