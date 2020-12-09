`include "mycpu.h"

module cp0_regfile(
    input             clk        ,
    input             reset      ,
    input             mtc0_we    ,
    input      [ 7:0] c0_raddr   ,  // c0_raddr = {c0_addr, c0_sel}
    input      [31:0] c0_wdata   ,
    input             wb_bd      ,
    input             wb_ex      ,
    input      [ 4:0] wb_excode  ,
    input             eret_flush ,
    input      [31:0] wb_pc      ,
    input      [31:0] wb_badvaddr,
    input      [ 5:0] ext_int_in ,
    output     [31:0] rdata      ,
    output reg [31:0] c0_epc     ,
    output            has_int    ,

    // about TLB
    output     [31:0] c0_entryhi ,
    output     [31:0] c0_entrylo0,
    output     [31:0] c0_entrylo1,
    output     [31:0] c0_index   ,

    input             tlbp       ,
    input             tlbp_found ,
    input      [ 3:0] tlbp_index ,
    // tlbr
    input             tlbr       ,
    input      [18:0] r_vpn2     ,
    input      [ 7:0] r_asid     ,
    input             r_g        ,
    input      [19:0] r_pfn0     ,
    input      [ 2:0] r_c0       ,
    input             r_d0       ,
    input             r_v0       ,
    input      [19:0] r_pfn1     ,
    input      [ 2:0] r_c1       ,
    input             r_d1       ,
    input             r_v1
);

wire        count_eq_compare;
wire [ 4:0] c0_addr;
wire [ 2:0] c0_sel ;
assign {c0_addr, c0_sel} = c0_raddr;

// CP0_STATUS
wire [31:0] c0_status      ;
wire [ 8:0] c0_status_31_23;
wire        c0_status_bev  ;
wire [ 5:0] c0_status_21_16;
reg  [ 7:0] c0_status_im   ;
wire [ 5:0] c0_status_7_2  ;
reg         c0_status_exl  ;
reg         c0_status_ie   ;
// 31:23
assign c0_status_31_23 = 9'b0;
// 22:22
assign c0_status_bev   = 1'b1;
// 21:16
assign c0_status_21_16 = 6'b0;
// 15:8
always @(posedge clk) begin
    if(mtc0_we && c0_addr == `CR_STATUS)
        c0_status_im <= c0_wdata[15:8];
end
// 7:2
assign c0_status_7_2   = 6'b0;
// 1:1
always @(posedge clk) begin
    if(reset)
        c0_status_exl <= 1'b0;
    else if(wb_ex)
        c0_status_exl <= 1'b1;
    else if(eret_flush)
        c0_status_exl <= 1'b0;
    else if(mtc0_we && c0_addr == `CR_STATUS)
        c0_status_exl <= c0_wdata[1];
end
// 0:0
always @(posedge clk) begin
    if(reset)
        c0_status_ie <= 1'b0;
    else if(mtc0_we && c0_addr == `CR_STATUS)
        c0_status_ie <= c0_wdata[0];
end
assign c0_status = {c0_status_31_23,    // 31:23
                    c0_status_bev  ,    // 22:22
                    c0_status_21_16,    // 21:16
                    c0_status_im   ,    // 15:8
                    c0_status_7_2  ,    // 7:2
                    c0_status_exl  ,    // 1:1
                    c0_status_ie        // 0:0
                   };

// CP0_CAUSE
wire [31:0] c0_cause;

reg         c0_cause_bd    ;
reg         c0_cause_ti    ;
wire [13:0] c0_cause_29_16 ;
reg  [7 :0] c0_cause_ip    ;
wire        c0_cause_7     ;
reg  [4 :0] c0_cause_excode;
wire [1 :0] c0_cause_1_0   ;
// 31:31
always @(posedge clk) begin
    if(reset)
        c0_cause_bd <= 1'b0;
    else if(wb_ex && !c0_status_exl)
        c0_cause_bd <= wb_bd;
end
// 30:30
always @(posedge clk) begin
    if(reset)
        c0_cause_ti <= 1'b0;
    else if(mtc0_we && c0_addr == `CR_COMPARE)
        c0_cause_ti <= 1'b0;
    else if(count_eq_compare)
        c0_cause_ti <= 1'b1;
end
// 29:16
assign c0_cause_29_16 = 14'b0;
// 15:10 cause_ip[7:2]
always @(posedge clk) begin
    if(reset)
        c0_cause_ip[7:2] <= 6'b0;
    else begin
        c0_cause_ip[7]   <= ext_int_in[5] | c0_cause_ti;
        c0_cause_ip[6:2] <= ext_int_in[4:0];
    end
end
// 9:8
always @(posedge clk) begin
    if(reset)
        c0_cause_ip[1:0] <= 2'b0;
    else if(mtc0_we && c0_addr == `CR_CAUSE)
        c0_cause_ip[1:0] <= c0_wdata[9:8];
end
// 7:7
assign c0_cause_7 = 1'b0;
// 6:2
always @(posedge clk) begin
    if(reset)
        c0_cause_excode <= 1'b0;
    else if(wb_ex)
        c0_cause_excode <= wb_excode;
end
// 1:0
assign c0_cause_1_0 = 2'b0;
assign c0_cause = {c0_cause_bd    ,    // 31:31
                   c0_cause_ti    ,    // 30:30
                   c0_cause_29_16 ,    // 29;16
                   c0_cause_ip    ,    // 15:8
                   c0_cause_7     ,    // 7:7
                   c0_cause_excode,    // 6:2
                   c0_cause_1_0        // 1:0
                  };

// CP0_EPC
always @(posedge clk) begin
    if(wb_ex && !c0_status_exl)
        c0_epc <= wb_bd ? wb_pc - 32'h4 : wb_pc;
    else if (mtc0_we && c0_addr == `CR_EPC)
        c0_epc <= c0_wdata;
end

// CP0_BadVAddr
reg [31: 0] c0_badvaddr;
always @(posedge clk) begin
    if (wb_ex && (wb_excode == `EX_ADEL || wb_excode == `EX_ADES))
        c0_badvaddr <= wb_badvaddr;
end

// CP0_COUNT
reg tick;
reg [31:0] c0_count;
always @(posedge clk) begin
    if(reset || (mtc0_we && c0_addr == `CR_COMPARE)) 
        tick <= 1'b0;
    else tick <= ~tick;
    if(mtc0_we && c0_addr==`CR_COUNT)
        c0_count <= c0_wdata;
    else if(tick)
        c0_count <= c0_count + 1'b1;
end

// CP0_COMPARE
reg [31:0] c0_compare;
always @(posedge clk) begin
    if(reset)
        c0_compare = 32'b0;
    else if(mtc0_we && c0_addr == `CR_COMPARE)
        c0_compare = c0_wdata;
end

assign count_eq_compare = c0_compare == c0_count;

// CP0_ENTRYHI
reg  [18:0] c0_entryhi_vpn2;
wire [ 4:0] c0_entryhi_12_8;
reg  [ 7:0] c0_entryhi_asid;
// 31:13
always @(posedge clk) begin
    if (reset)
        c0_entryhi_vpn2 <= 19'h0;
    else if (mtc0_we && c0_addr == `CR_ENTRYHI)
        c0_entryhi_vpn2 <= c0_wdata[31:13];
    else if (tlbr)
        c0_entryhi_vpn2 <= r_vpn2;
    // else if((wb_excode == 5'h01 || wb_excode == 5'h02 || wb_excode==5'h03) && wb_ex)
    //     // c0_entryhi_vpn2<= wb_badvaddr[31:12];
    //     c0_entryhi_vpn2 <= wb_badvaddr[31:13];
end
// 12:8
assign c0_entryhi_12_8 = 5'b0;
// 7:0
always @(posedge clk) begin
    if (reset)
        c0_entryhi_asid <= 8'h0;
    else if (mtc0_we && c0_addr == `CR_ENTRYHI)
        c0_entryhi_asid <= c0_wdata[7:0];
    else if (tlbr)
        c0_entryhi_asid <= r_asid;
end
assign c0_entryhi = {c0_entryhi_vpn2,   // 31:13
                     c0_entryhi_12_8,   // 12:8
                     c0_entryhi_asid    // 7:0
                    };

// CP0_ENTRYLO0
wire [ 5:0] c0_entrylo0_31_26;
reg  [19:0] c0_entrylo0_pfn0 ;
reg  [ 2:0] c0_entrylo0_C    ;
reg         c0_entrylo0_D    ;
reg         c0_entrylo0_V    ;
reg         c0_entrylo0_G    ;
// 31:26
assign c0_entrylo0_31_26 = 6'b0;
// 25:6
always @(posedge clk) begin
    if (reset)
        c0_entrylo0_pfn0 <= 20'h0;
    else if (mtc0_we && c0_addr == `CR_ENTRYLO0)
        c0_entrylo0_pfn0 <= c0_wdata[25:6];
    else if (tlbr)
        c0_entrylo0_pfn0 <= r_pfn0;
end
// 5:0
// c0_entrylo0_C, c0_entrylo0_D, c0_entrylo0_V, c0_entrylo0_G
always @(posedge clk) begin
    if (reset)
        {c0_entrylo0_C, c0_entrylo0_D, c0_entrylo0_V, c0_entrylo0_G} <= 6'h0;
    else if (mtc0_we && c0_addr == `CR_ENTRYLO0)
        {c0_entrylo0_C, c0_entrylo0_D, c0_entrylo0_V, c0_entrylo0_G} <= c0_wdata[5:0];
    else if (tlbr)
        {c0_entrylo0_C, c0_entrylo0_D, c0_entrylo0_V, c0_entrylo0_G} <= {r_c0, r_d0, r_v0, r_g};
end
assign c0_entrylo0 = {c0_entrylo0_31_26,  // 31:26
                      c0_entrylo0_pfn0 ,  // 25:6
                      c0_entrylo0_C    ,  // 5:3
                      c0_entrylo0_D    ,  // 2:2
                      c0_entrylo0_V    ,  // 1:1
                      c0_entrylo0_G       // 0:0
                     };

// CP0_ENTRYLO1
wire [ 5:0] c0_entrylo1_31_26;
reg  [19:0] c0_entrylo1_pfn1 ;
reg  [ 2:0] c0_entrylo1_C    ;
reg         c0_entrylo1_D    ;
reg         c0_entrylo1_V    ;
reg         c0_entrylo1_G    ;
// 31:26
assign c0_entrylo1_31_26 = 6'b0;
// 25:6
always @(posedge clk) begin
    if (reset)
        c0_entrylo1_pfn1 <= 20'h0;
    else if (mtc0_we && c0_addr == `CR_ENTRYLO1)
        c0_entrylo1_pfn1 <= c0_wdata[25:6];
    else if (tlbr)
        c0_entrylo1_pfn1 <= r_pfn1;
end
// 5:0
// c0_entrylo1_C, c0_entrylo1_D, c0_entrylo1_V, c0_entrylo1_G
always @(posedge clk) begin
    if (reset)
        {c0_entrylo1_C, c0_entrylo1_D, c0_entrylo1_V, c0_entrylo1_G} <= 6'h0;
    else if (mtc0_we && c0_addr == `CR_ENTRYLO1)
        {c0_entrylo1_C, c0_entrylo1_D, c0_entrylo1_V, c0_entrylo1_G} <= c0_wdata[5:0];
    else if (tlbr)
        {c0_entrylo1_C, c0_entrylo1_D, c0_entrylo1_V, c0_entrylo1_G} <= {r_c1, r_d1, r_v1, r_g};
end
assign c0_entrylo1 = {c0_entrylo1_31_26,  // 31:26
                      c0_entrylo1_pfn1 ,  // 25:6
                      c0_entrylo1_C    ,  // 5:3
                      c0_entrylo1_D    ,  // 2:2
                      c0_entrylo1_V    ,  // 1:1
                      c0_entrylo1_G       // 0:0
                     };

// CP0_INDEX
reg         c0_index_p    ;
wire [26:0] c0_index_30_4 ;
reg  [ 3:0] c0_index_index;
// 31:31
always@(posedge clk) begin
    if (reset)
        c0_index_p <= 1'b0;
    // else if (mtc0_we && c0_addr == `CR_INDEX)
        // c0_index_p <= c0_wdata[31];
    else if (tlbp && !tlbp_found)
        c0_index_p <= 1'b1;
    else if (tlbp && tlbp_found)
        c0_index_p <= 1'b0;
end
// 30:4
assign c0_index_30_4 = 27'b0;
// 3:0
always@(posedge clk) begin
    if (reset)
        c0_index_index <= 4'h0;
    else if (mtc0_we && c0_addr == `CR_INDEX)
        c0_index_index <= c0_wdata[3:0];
    else if (tlbp && tlbp_found)
        c0_index_index <= tlbp_index;
end
assign c0_index = {c0_index_p    ,  // 31:31
                   c0_index_30_4 ,  // 30:4
                   c0_index_index   // 3:0
                  };

// read data
assign rdata = (c0_addr == `CR_STATUS  ) ? c0_status  :
               (c0_addr == `CR_CAUSE   ) ? c0_cause   :
               (c0_addr == `CR_EPC     ) ? c0_epc     :
               (c0_addr == `CR_COMPARE ) ? c0_compare :
               (c0_addr == `CR_BADVADDR) ? c0_badvaddr:
               (c0_addr == `CR_ENTRYHI ) ? c0_entryhi :
               (c0_addr == `CR_ENTRYLO0) ? c0_entrylo0:
               (c0_addr == `CR_ENTRYLO1) ? c0_entrylo1:
               (c0_addr == `CR_INDEX   ) ? c0_index   :
               32'b0;

// wire has_int;
assign has_int = (c0_cause_ip[7:0] & c0_status_im[7:0]) != 8'h00 && c0_status_ie == 1'b1 && c0_status_exl == 1'b0;

endmodule
