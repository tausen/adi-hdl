// ***************************************************************************
// ***************************************************************************
// Copyright 2022 (c) Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************
`timescale 1ns/1ps

module axi_tdd_ng_regmap #(
  parameter  ID = 0,
  parameter  CHANNEL_COUNT = 8,
  parameter  REGISTER_WIDTH = 32,
  parameter  BURST_COUNT_WIDTH = 32,
  parameter  SYNC_EXTERNAL = 0,
  parameter  SYNC_INTERNAL = 1,
  parameter  SYNC_EXTERNAL_CDC = 0,
  parameter  SYNC_COUNT_WIDTH = 64) (

  // tdd clock
  input  logic                         tdd_clk,

  // tdd interface control
  output logic                         tdd_enable,
  output logic [CHANNEL_COUNT-1:0]     tdd_channel_en,
  output logic [CHANNEL_COUNT-1:0]     tdd_channel_pol,
  output logic [BURST_COUNT_WIDTH-1:0] tdd_burst_count,
  output logic [REGISTER_WIDTH-1:0]    tdd_startup_delay,
  output logic [REGISTER_WIDTH-1:0]    tdd_frame_length,
  output logic [REGISTER_WIDTH-1:0]    tdd_channel_on  [0:CHANNEL_COUNT-1],
  output logic [REGISTER_WIDTH-1:0]    tdd_channel_off [0:CHANNEL_COUNT-1],
  output logic [SYNC_COUNT_WIDTH-1:0]  tdd_sync_period,
  output logic                         tdd_sync_ext,
  output logic                         tdd_sync_int,
  output logic                         tdd_sync_soft,

  // bus interface
  input  logic                         up_rstn,
  input  logic                         up_clk,
  input  logic                         up_wreq,
  input  logic [13:0]                  up_waddr,
  input  logic [31:0]                  up_wdata,
  output logic                         up_wack,
  input  logic                         up_rreq,
  input  logic [13:0]                  up_raddr,
  output logic [31:0]                  up_rdata,
  output logic                         up_rack);

  // package import
  import axi_tdd_ng_pkg::*;

  // internal registers
  logic [31:0]                  up_scratch;
  logic                         up_tdd_enable;
  logic                         up_tdd_sync_ext;
  logic                         up_tdd_sync_int;
  logic                         up_tdd_sync_soft;
  logic [CHANNEL_COUNT-1:0]     up_tdd_channel_en;
  logic [CHANNEL_COUNT-1:0]     up_tdd_channel_pol;
  logic [BURST_COUNT_WIDTH-1:0] up_tdd_burst_count;
  logic [REGISTER_WIDTH-1:0]    up_tdd_startup_delay;
  logic [REGISTER_WIDTH-1:0]    up_tdd_frame_length;
  logic [REGISTER_WIDTH-1:0]    up_tdd_channel_on  [0:CHANNEL_COUNT-1];
  logic [REGISTER_WIDTH-1:0]    up_tdd_channel_off [0:CHANNEL_COUNT-1];

  //internal wires
  logic [31:0]                  status_synth_params_s;
  logic [31:0]                  up_tdd_channel_en_s;
  logic [31:0]                  up_tdd_channel_pol_s;
  logic [31:0]                  up_tdd_burst_count_s;
  logic [31:0]                  up_tdd_startup_delay_s;
  logic [31:0]                  up_tdd_frame_length_s;
  logic [63:0]                  up_tdd_sync_period_s;
  logic [31:0]                  up_tdd_channel_on_s  [0:31];
  logic [31:0]                  up_tdd_channel_off_s [0:31];

  //initial values
  initial begin
    up_rdata = 32'b0;
    up_wack = 1'b0;
    up_rack = 1'b0;
    up_scratch = 32'b0;
    up_tdd_enable = 1'b0;
    up_tdd_sync_ext = 1'b0;
    up_tdd_sync_int = 1'b0;
    up_tdd_sync_soft = 1'b0;
    up_tdd_channel_en = 'd0;
    up_tdd_channel_pol = 'd0;
    up_tdd_burst_count = 'd0;
    up_tdd_startup_delay = 'd0;
    up_tdd_frame_length = 'd0;
    up_tdd_channel_on  = '{default:0};
    up_tdd_channel_off = '{default:0};
  end

  //read-only synthesis parameters
  assign status_synth_params_s = {
                 /*31:24 */  2'b0, SYNC_COUNT_WIDTH[5:0],
                 /*23:16 */  3'b0, BURST_COUNT_WIDTH[4:0],
                 /*15: 8 */  3'b0, REGISTER_WIDTH[4:0],
                 /* 7: 0 */  SYNC_EXTERNAL_CDC,
                             SYNC_EXTERNAL,
                             SYNC_INTERNAL,
                             CHANNEL_COUNT[4:0]};

  // processor write interface

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_wack <= 1'b0;
      up_scratch <= 32'b0;
      up_tdd_enable <= 1'b0;
      up_tdd_sync_ext <= 1'b0;
      up_tdd_sync_int <= 1'b0;
      up_tdd_sync_soft <= 1'b0;
      up_tdd_channel_en <= 'd0;
      up_tdd_channel_pol <= 'd0;
      up_tdd_startup_delay <= 'd0;
      up_tdd_frame_length <= 'd0;
      up_tdd_burst_count <= 'd0;
    end else begin
      up_wack <= up_wreq;
      if ((up_wreq == 1'b1) && (up_waddr[7:0] == ADDR_TDD_SCRATCH)) begin
        up_scratch <= up_wdata;
      end
      if ((up_wreq == 1'b1) && (up_waddr[7:0] == ADDR_TDD_CONTROL)) begin
        {up_tdd_sync_soft,
         up_tdd_sync_int,
         up_tdd_sync_ext,
         up_tdd_enable} <= up_wdata[3:0];
      end
      if ((up_wreq == 1'b1) && (up_waddr[7:0] == ADDR_TDD_CH_ENABLE) && !up_tdd_enable) begin
        up_tdd_channel_en <= up_wdata[CHANNEL_COUNT-1:0];
      end
      if ((up_wreq == 1'b1) && (up_waddr[7:0] == ADDR_TDD_CH_POLARITY) && !up_tdd_enable) begin
        up_tdd_channel_pol <= up_wdata[CHANNEL_COUNT-1:0];
      end
      if ((up_wreq == 1'b1) && (up_waddr[7:0] == ADDR_TDD_BURST_COUNT) && !up_tdd_enable) begin
        up_tdd_burst_count <= up_wdata[BURST_COUNT_WIDTH-1:0];
      end
      if ((up_wreq == 1'b1) && (up_waddr[7:0] == ADDR_TDD_STARTUP_DELAY) && !up_tdd_enable) begin
        up_tdd_startup_delay <= up_wdata[REGISTER_WIDTH-1:0];
      end
      if ((up_wreq == 1'b1) && (up_waddr[7:0] == ADDR_TDD_FRAME_LENGTH) && !up_tdd_enable) begin
        up_tdd_frame_length <= up_wdata[REGISTER_WIDTH-1:0];
      end
    end
  end

  assign up_tdd_channel_en_s = {{(32-CHANNEL_COUNT){1'b0}}, up_tdd_channel_en};
  assign up_tdd_channel_pol_s = {{(32-CHANNEL_COUNT){1'b0}}, up_tdd_channel_pol};
  assign up_tdd_burst_count_s = {{(32-BURST_COUNT_WIDTH){1'b0}}, up_tdd_burst_count};
  assign up_tdd_startup_delay_s = {{(32-REGISTER_WIDTH){1'b0}}, up_tdd_startup_delay};
  assign up_tdd_frame_length_s = {{(32-REGISTER_WIDTH){1'b0}}, up_tdd_frame_length};

  // internal sync counter generation (low and high)

  generate
    if (SYNC_COUNT_WIDTH>32) begin

      logic [31:0]                      up_tdd_sync_period_low;
      logic [(SYNC_COUNT_WIDTH-32-1):0] up_tdd_sync_period_high;

      always @(negedge up_rstn or posedge up_clk) begin
        if (up_rstn == 0) begin
          up_tdd_sync_period_low <= 32'b0;
          up_tdd_sync_period_high <= 'd0;
        end else begin
          if ((up_wreq == 1'b1) && (up_waddr[7:0] == ADDR_TDD_SYNC_CNT_LOW) && !up_tdd_enable) begin
            up_tdd_sync_period_low <= up_wdata[31:0];
          end
          if ((up_wreq == 1'b1) && (up_waddr[7:0] == ADDR_TDD_SYNC_CNT_HIGH) && !up_tdd_enable) begin
            up_tdd_sync_period_high <= up_wdata[(SYNC_COUNT_WIDTH-32-1):0];
          end
        end
      end

      assign up_tdd_sync_period_s[31:0] = up_tdd_sync_period_low;
      assign up_tdd_sync_period_s[63:32] = {{(64-SYNC_COUNT_WIDTH){1'b0}}, up_tdd_sync_period_high};
      assign tdd_sync_period = {up_tdd_sync_period_high, up_tdd_sync_period_low}; //skipping CDC

    end else begin
      if (SYNC_COUNT_WIDTH>0) begin

        logic [SYNC_COUNT_WIDTH-1:0] up_tdd_sync_period_low;

        always @(negedge up_rstn or posedge up_clk) begin
          if (up_rstn == 0) begin
            up_tdd_sync_period_low <= 'd0;
          end else begin
            if ((up_wreq == 1'b1) && (up_waddr[7:0] == ADDR_TDD_SYNC_CNT_LOW) && !up_tdd_enable) begin
              up_tdd_sync_period_low <= up_wdata[(SYNC_COUNT_WIDTH-1):0];
            end
          end
        end

        assign up_tdd_sync_period_s[31:0] = {{(32-SYNC_COUNT_WIDTH){1'b0}}, up_tdd_sync_period_low};
        assign up_tdd_sync_period_s[63:32] = 32'b0;
        assign tdd_sync_period = up_tdd_sync_period_low; //skipping CDC

      end else begin
        assign up_tdd_sync_period_s[31:0] = 32'b0;
        assign up_tdd_sync_period_s[63:32] = 32'b0;
        assign tdd_sync_period = 'd0;
      end
    end
  endgenerate 

  // channel register generation

  genvar i;
  generate

    for (i=0; i<CHANNEL_COUNT; i=i+1) begin
      always @(negedge up_rstn or posedge up_clk) begin
        if (up_rstn == 0) begin
          up_tdd_channel_on[i] <= 'd0;
          up_tdd_channel_off[i] <= 'd0;
        end else begin
          if ((up_wreq == 1'b1) && (up_waddr[7:0] == (ADDR_TDD_CH_ON + i*2)) && !up_tdd_enable) begin
            up_tdd_channel_on[i] <= up_wdata[REGISTER_WIDTH-1:0];
          end
          if ((up_wreq == 1'b1) && (up_waddr[7:0] == (ADDR_TDD_CH_OFF + i*2)) && !up_tdd_enable) begin
            up_tdd_channel_off[i] <= up_wdata[REGISTER_WIDTH-1:0];
          end
        end
      end

      assign up_tdd_channel_on_s[i] = {{(32-REGISTER_WIDTH){1'b0}}, up_tdd_channel_on[i]};
      assign up_tdd_channel_off_s[i] = {{(32-REGISTER_WIDTH){1'b0}}, up_tdd_channel_off[i]};
    end

    if (CHANNEL_COUNT<32) begin
      assign up_tdd_channel_on_s[CHANNEL_COUNT:31] = '{default:0};
      assign up_tdd_channel_off_s[CHANNEL_COUNT:31] = '{default:0};
    end

  endgenerate

  // processor read interface

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_rack <= 1'b0;
      up_rdata <= 32'b0;
    end else begin
      up_rack <= up_rreq;
      if (up_rreq == 1'b1) begin
        case (up_raddr[7:0])
          ADDR_TDD_VERSION       : up_rdata <= PCORE_VERSION;
          ADDR_TDD_ID            : up_rdata <= ID[31:0];
          ADDR_TDD_SCRATCH       : up_rdata <= up_scratch;
          ADDR_TDD_IDENTIFY      : up_rdata <= PCORE_MAGIC;
          ADDR_TDD_INTERFACE     : up_rdata <= status_synth_params_s;
          ADDR_TDD_CONTROL       : up_rdata <= {28'b0, up_tdd_sync_soft,
                                                       up_tdd_sync_int,
                                                       up_tdd_sync_ext,
                                                       up_tdd_enable};
          ADDR_TDD_CH_ENABLE     : up_rdata <= up_tdd_channel_en_s;
          ADDR_TDD_CH_POLARITY   : up_rdata <= up_tdd_channel_pol_s;
          ADDR_TDD_BURST_COUNT   : up_rdata <= up_tdd_burst_count_s;
          ADDR_TDD_STARTUP_DELAY : up_rdata <= up_tdd_startup_delay_s;
          ADDR_TDD_FRAME_LENGTH  : up_rdata <= up_tdd_frame_length_s;
          ADDR_TDD_SYNC_CNT_LOW  : up_rdata <= up_tdd_sync_period_s[31:0];
          ADDR_TDD_SYNC_CNT_HIGH : up_rdata <= up_tdd_sync_period_s[63:32];
          ADDR_TDD_CH_ON  + CH0  : up_rdata <= up_tdd_channel_on_s[CH0];
          ADDR_TDD_CH_OFF + CH0  : up_rdata <= up_tdd_channel_off_s[CH0];
          ADDR_TDD_CH_ON  + CH1  : up_rdata <= up_tdd_channel_on_s[CH1];
          ADDR_TDD_CH_OFF + CH1  : up_rdata <= up_tdd_channel_off_s[CH1];
          ADDR_TDD_CH_ON  + CH2  : up_rdata <= up_tdd_channel_on_s[CH2];
          ADDR_TDD_CH_OFF + CH2  : up_rdata <= up_tdd_channel_off_s[CH2];
          ADDR_TDD_CH_ON  + CH3  : up_rdata <= up_tdd_channel_on_s[CH3];
          ADDR_TDD_CH_OFF + CH3  : up_rdata <= up_tdd_channel_off_s[CH3];
          ADDR_TDD_CH_ON  + CH4  : up_rdata <= up_tdd_channel_on_s[CH4];
          ADDR_TDD_CH_OFF + CH4  : up_rdata <= up_tdd_channel_off_s[CH4];
          ADDR_TDD_CH_ON  + CH5  : up_rdata <= up_tdd_channel_on_s[CH5];
          ADDR_TDD_CH_OFF + CH5  : up_rdata <= up_tdd_channel_off_s[CH5];
          ADDR_TDD_CH_ON  + CH6  : up_rdata <= up_tdd_channel_on_s[CH6];
          ADDR_TDD_CH_OFF + CH6  : up_rdata <= up_tdd_channel_off_s[CH6];
          ADDR_TDD_CH_ON  + CH7  : up_rdata <= up_tdd_channel_on_s[CH7];
          ADDR_TDD_CH_OFF + CH7  : up_rdata <= up_tdd_channel_off_s[CH7];
          ADDR_TDD_CH_ON  + CH8  : up_rdata <= up_tdd_channel_on_s[CH8];
          ADDR_TDD_CH_OFF + CH8  : up_rdata <= up_tdd_channel_off_s[CH8];
          ADDR_TDD_CH_ON  + CH9  : up_rdata <= up_tdd_channel_on_s[CH9];
          ADDR_TDD_CH_OFF + CH9  : up_rdata <= up_tdd_channel_off_s[CH9];
          ADDR_TDD_CH_ON  + CH10 : up_rdata <= up_tdd_channel_on_s[CH10];
          ADDR_TDD_CH_OFF + CH10 : up_rdata <= up_tdd_channel_off_s[CH10];
          ADDR_TDD_CH_ON  + CH11 : up_rdata <= up_tdd_channel_on_s[CH11];
          ADDR_TDD_CH_OFF + CH11 : up_rdata <= up_tdd_channel_off_s[CH11];
          ADDR_TDD_CH_ON  + CH12 : up_rdata <= up_tdd_channel_on_s[CH12];
          ADDR_TDD_CH_OFF + CH12 : up_rdata <= up_tdd_channel_off_s[CH12];
          ADDR_TDD_CH_ON  + CH13 : up_rdata <= up_tdd_channel_on_s[CH13];
          ADDR_TDD_CH_OFF + CH13 : up_rdata <= up_tdd_channel_off_s[CH13];
          ADDR_TDD_CH_ON  + CH14 : up_rdata <= up_tdd_channel_on_s[CH14];
          ADDR_TDD_CH_OFF + CH14 : up_rdata <= up_tdd_channel_off_s[CH14];
          ADDR_TDD_CH_ON  + CH15 : up_rdata <= up_tdd_channel_on_s[CH15];
          ADDR_TDD_CH_OFF + CH15 : up_rdata <= up_tdd_channel_off_s[CH15];
          ADDR_TDD_CH_ON  + CH16 : up_rdata <= up_tdd_channel_on_s[CH16];
          ADDR_TDD_CH_OFF + CH16 : up_rdata <= up_tdd_channel_off_s[CH16];
          ADDR_TDD_CH_ON  + CH17 : up_rdata <= up_tdd_channel_on_s[CH17];
          ADDR_TDD_CH_OFF + CH17 : up_rdata <= up_tdd_channel_off_s[CH17];
          ADDR_TDD_CH_ON  + CH18 : up_rdata <= up_tdd_channel_on_s[CH18];
          ADDR_TDD_CH_OFF + CH18 : up_rdata <= up_tdd_channel_off_s[CH18];
          ADDR_TDD_CH_ON  + CH19 : up_rdata <= up_tdd_channel_on_s[CH19];
          ADDR_TDD_CH_OFF + CH19 : up_rdata <= up_tdd_channel_off_s[CH19];
          ADDR_TDD_CH_ON  + CH20 : up_rdata <= up_tdd_channel_on_s[CH20];
          ADDR_TDD_CH_OFF + CH20 : up_rdata <= up_tdd_channel_off_s[CH20];
          ADDR_TDD_CH_ON  + CH21 : up_rdata <= up_tdd_channel_on_s[CH21];
          ADDR_TDD_CH_OFF + CH21 : up_rdata <= up_tdd_channel_off_s[CH21];
          ADDR_TDD_CH_ON  + CH22 : up_rdata <= up_tdd_channel_on_s[CH22];
          ADDR_TDD_CH_OFF + CH22 : up_rdata <= up_tdd_channel_off_s[CH22];
          ADDR_TDD_CH_ON  + CH23 : up_rdata <= up_tdd_channel_on_s[CH23];
          ADDR_TDD_CH_OFF + CH23 : up_rdata <= up_tdd_channel_off_s[CH23];
          ADDR_TDD_CH_ON  + CH24 : up_rdata <= up_tdd_channel_on_s[CH24];
          ADDR_TDD_CH_OFF + CH24 : up_rdata <= up_tdd_channel_off_s[CH24];
          ADDR_TDD_CH_ON  + CH25 : up_rdata <= up_tdd_channel_on_s[CH25];
          ADDR_TDD_CH_OFF + CH25 : up_rdata <= up_tdd_channel_off_s[CH25];
          ADDR_TDD_CH_ON  + CH26 : up_rdata <= up_tdd_channel_on_s[CH26];
          ADDR_TDD_CH_OFF + CH26 : up_rdata <= up_tdd_channel_off_s[CH26];
          ADDR_TDD_CH_ON  + CH27 : up_rdata <= up_tdd_channel_on_s[CH27];
          ADDR_TDD_CH_OFF + CH27 : up_rdata <= up_tdd_channel_off_s[CH27];
          ADDR_TDD_CH_ON  + CH28 : up_rdata <= up_tdd_channel_on_s[CH28];
          ADDR_TDD_CH_OFF + CH28 : up_rdata <= up_tdd_channel_off_s[CH28];
          ADDR_TDD_CH_ON  + CH29 : up_rdata <= up_tdd_channel_on_s[CH29];
          ADDR_TDD_CH_OFF + CH29 : up_rdata <= up_tdd_channel_off_s[CH29];
          ADDR_TDD_CH_ON  + CH30 : up_rdata <= up_tdd_channel_on_s[CH30];
          ADDR_TDD_CH_OFF + CH30 : up_rdata <= up_tdd_channel_off_s[CH30];
          ADDR_TDD_CH_ON  + CH31 : up_rdata <= up_tdd_channel_on_s[CH31];
          ADDR_TDD_CH_OFF + CH31 : up_rdata <= up_tdd_channel_off_s[CH31];
          default: up_rdata <= 32'b0;
        endcase
      end else begin
        up_rdata <= 32'b0;
      end
    end
  end

  // control signals CDC

  sync_data #(
    .NUM_OF_BITS (4),
    .ASYNC_CLK (1)
  ) i_control_sync (
    .in_clk (up_clk),
    .in_data ({up_tdd_sync_soft,
               up_tdd_sync_int,
               up_tdd_sync_ext,
               up_tdd_enable}),
    .out_clk (tdd_clk),
    .out_data ({tdd_sync_soft,
                tdd_sync_int,
                tdd_sync_ext,
                tdd_enable}));

  // skipping the CDC for the rest of the registers since the register writes are gated with module enable
  // furthermore, updating the async domain registers is also conditioned by the synchronized module enable

  assign tdd_channel_en = up_tdd_channel_en;
  assign tdd_channel_pol = up_tdd_channel_pol;
  assign tdd_burst_count = up_tdd_burst_count;
  assign tdd_startup_delay = up_tdd_startup_delay;
  assign tdd_frame_length = up_tdd_frame_length;
  assign tdd_channel_on  = up_tdd_channel_on;
  assign tdd_channel_off = up_tdd_channel_off;

endmodule

