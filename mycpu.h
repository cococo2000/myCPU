`ifndef MYCPU_H
    `define MYCPU_H
    // width of bus
    `define BR_BUS_WD       35
    `define FS_TO_DS_BUS_WD 71
    `define DS_TO_ES_BUS_WD 207
    `define ES_TO_MS_BUS_WD 128
    `define MS_TO_WS_BUS_WD 123
    `define WS_TO_RF_BUS_WD 41
    `define ES_FWD_BUS_WD   40
    `define MS_FWD_BUS_WD   43
    // cp0_reg
    `define CR_BADVADDR     8
    `define CR_COUNT        9
    `define CR_COMPARE      11
    `define CR_STATUS       12
    `define CR_CAUSE        13
    `define CR_EPC          14
    // EXCEPTION CODE (cp0_cause ExcCode)
    `define EX_INT          5'h00
    `define EX_ADEL         5'h04
    `define EX_ADES         5'h05
    `define EX_SYS          5'h08
    `define EX_BP           5'h09
    `define EX_RI           5'h0a
    `define EX_OV           5'h0c
`endif
