`include "mycpu.h"

module cp0_regfile(
    input        clk       ,
    input        reset     ,
    input        mtc0_we   ,
    input [ 7:0] c0_raddr ,
    input [31:0] c0_wdata  ,
    input        wb_bd     ,
    input        wb_ex     ,
    input [ 4:0] wb_excode ,
    input        eret_flush,
    input [31:0] wb_pc     ,
    input [31:0] wb_badvaddr,
    output[31:0] rdata     ,
    output reg [31:0] c0_epc,
    output       has_int
);

wire count_eq_compare;
wire [ 5:0] ext_int_in;
wire [ 4:0] c0_addr;
wire [ 2:0] c0_sel;


// assign count_eq_compare = 1'b0;
assign ext_int_in = 6'b0;
assign {c0_addr, c0_sel} = c0_raddr;

// CP0_STATUS
wire [31:0] c0_status;
wire [ 8:0] c0_status_31_23;
wire        c0_status_bev;
wire [ 5:0] c0_status_21_16;
reg  [ 7:0] c0_status_im;
wire [ 5:0] c0_status_7_2;
reg         c0_status_exl;
reg         c0_status_ie;
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

reg         c0_cause_bd;
reg         c0_cause_ti;
wire [13:0] c0_cause_29_16;
reg  [7 :0] c0_cause_ip;
wire        c0_cause_7;
reg  [4 :0] c0_cause_excode;
wire [1 :0] c0_cause_1_0;
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
    else if(count_eq_compare)  // not done, will done in lab9
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
assign c0_cause_7     = 1'b0;
// 6:2
always @(posedge clk) begin
    if(reset)
        c0_cause_excode <= 1'b0;
    else if(wb_ex)
        c0_cause_excode <= wb_excode;
end
// 1:0
assign c0_cause_1_0   = 2'b0;
assign c0_cause = { c0_cause_bd    ,    // 31:31
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
always @(posedge |clk) begin
    if (wb_ex && (wb_excode == `EX_ADEL || wb_excode == `EX_ADES ||wb_excode == `EX_RI))
        c0_badvaddr <= wb_badvaddr;
end

// CP0_COUNT
reg tick;
reg [31:0] c0_count;
always @(posedge |clk) begin
    if(reset || (mtc0_we && c0_addr == `CR_COMPARE)) 
        tick <= 1'b0;
    else tick <= ~tick;
    if(mtc0_we && c0_addr==`CR_COUNT)
        c0_count <= c0_wdata;
    else if(tick)
        c0_count <= c0_count + 1'b1;
end

reg [31:0] c0_compare;
always @(posedge |clk) begin
    if(reset)
        c0_compare = 32'b0;
    else if(mtc0_we && c0_addr == `CR_COMPARE)
        c0_compare = c0_wdata;
end

assign count_eq_compare = c0_compare == c0_count;
// read data
assign rdata = (c0_addr == `CR_STATUS ) ? c0_status :
               (c0_addr == `CR_CAUSE  ) ? c0_cause  :
               (c0_addr == `CR_EPC    ) ? c0_epc    :
               (c0_addr == `CR_COMPARE) ? c0_compare:
               (c0_addr == `CR_BADVADDR)? c0_badvaddr:
               32'b0;

// wire has_int;
assign has_int = (c0_cause_ip[7:0] & c0_status_im[7:0])!=8'h00 && c0_status_ie==1'b1 && c0_status_exl==1'b0;

endmodule
