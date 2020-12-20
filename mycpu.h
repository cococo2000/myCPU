`ifndef MYCPU_H
    `define MYCPU_H
    // width of bus
    `define BR_BUS_WD       35
    `define FS_TO_DS_BUS_WD 72
    `define DS_TO_ES_BUS_WD 211
    `define ES_TO_MS_BUS_WD 132
    `define MS_TO_WS_BUS_WD 126
    `define WS_TO_RF_BUS_WD 41
    `define ES_FWD_BUS_WD   40
    `define MS_FWD_BUS_WD   44

    // cp0_reg
    `define CR_BADVADDR     8
    `define CR_COUNT        9
    `define CR_COMPARE      11
    `define CR_STATUS       12
    `define CR_CAUSE        13
    `define CR_EPC          14
    // about TLB
    `define CR_ENTRYHI      10
    `define CR_ENTRYLO0     2
    `define CR_ENTRYLO1     3
    `define CR_INDEX        0

    // EXCEPTION CODE (cp0_cause ExcCode)
    `define EX_INT          5'h00
    `define EX_ADEL         5'h04
    `define EX_ADES         5'h05
    `define EX_SYS          5'h08
    `define EX_BP           5'h09
    `define EX_RI           5'h0a
    `define EX_OV           5'h0c
    // TLB ex
    `define EX_MOD          5'h01
    `define EX_TLBL         5'h02
    `define EX_TLBS         5'h03
`endif
