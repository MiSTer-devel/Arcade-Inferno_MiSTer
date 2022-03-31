//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

//assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

assign LED_USER  = ioctl_download;

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.INFERNO;;",
	"-;",
	"H0O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",	
	"h4O67,Fire,4-way,Move with Fire,Second Joystick;",	
	"-;",
	"OA,Advance,Off,On;",
	"OB,Auto Up,Off,On;",
	"OC,High Score Reset,Off,On;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Fire 3,Fire 4,Start 1P,Start 2P,Coin,Pause;",
	"V,v",`BUILD_DATE 
};

wire        forced_scandoubler;
wire        direct_video;
wire [21:0] gamma_bus;
wire        video_rotated;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [ 7:0] ioctl_dout;
wire [15:0] ioctl_index;

wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;

wire [31:0] joy1, joy2;
wire [31:0] joy = joy1 | joy2;

wire [15:0] joy1a, joy2a;
wire [15:0] joya = j2 ? joy2a : joy1a;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.buttons(buttons),
	.status(status),
	.status_menumask({direct_video}),

	.forced_scandoubler(forced_scandoubler),
	.video_rotated(video_rotated),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joy1),
	.joystick_1(joy2)
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
wire pll_locked;
wire clk_48,clk_12;
assign clk_sys=clk_12;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_48),
	.outclk_1(clk_12),
	.locked(pll_locked)
);

wire reset = RESET | status[0] | buttons[1];

//////////////////////////////////////////////////////////////////

wire m_start1  = joy[10];
wire m_start2  = joy[11];
wire m_coin1   = joy[12];
wire m_advance = joy[13];
wire m_autoup  = joy[14];
wire m_pause   = joy[15];

wire m_right1  = joy1[0];
wire m_left1   = joy1[1];
wire m_down1   = joy1[2];
wire m_up1     = joy1[3];
wire m_fire1a  = joy1[4];
wire m_fire1b  = joy1[5];
wire m_fire1c  = joy1[6];
wire m_fire1d  = joy1[7];
wire m_fire1e  = joy1[8];
wire m_fire1f  = joy1[9];

wire m_right2  = joy2[0];
wire m_left2   = joy2[1];
wire m_down2   = joy2[2];
wire m_up2     = joy2[3];
wire m_fire2a  = joy2[4];
wire m_fire2b  = joy2[5];
wire m_fire2c  = joy2[6];
wire m_fire2d  = joy2[7];
wire m_fire2e  = joy2[8];
wire m_fire2f  = joy2[9];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
wire m_fire_c  = m_fire1c | m_fire2c;
wire m_fire_d  = m_fire1d | m_fire2d;
wire m_fire_e  = m_fire1e | m_fire2e;
wire m_fire_f  = m_fire1f | m_fire2f;

reg  [7:0] JA;
reg  [7:0] JB;
reg  [2:0] BTN;

always @(*) begin
	JA = 0;
	JB = 0;
	BTN = 0;

	BTN = { m_start1, m_start2, m_coin1 };
	JA  = ~{ status[7] ? {m_right2, m_left2, m_down2, m_up2} : status[6] ? {m_right, m_left, m_down, m_up} : {m_fire_a, m_fire_d, m_fire_b, m_fire_c},
				status[7] ? {m_right1, m_left1, m_down1, m_up1} : {m_right, m_left, m_down, m_up}};
	JB  = JA;	
end	

wire [3:0] dmx = m_left ? 4'd0 : m_right ? 4'd8 : 4'd7;
wire [3:0] dmy = m_down ? 4'd0 : m_up    ? 4'd8 : 4'd7;

wire [3:0] amx = ($signed(joya[7:0]) < -96) ? 4'd0  :
                 ($signed(joya[7:0]) < -64) ? 4'd4  :
                 ($signed(joya[7:0]) < -32) ? 4'd6  :
                 ($signed(joya[7:0]) >  96) ? 4'd8  :
                 ($signed(joya[7:0]) >  64) ? 4'd9  :
                 ($signed(joya[7:0]) >  32) ? 4'd11 : 4'd7;

wire [3:0] amy = ($signed(joya[15:8]) < -96) ? 4'd8  :
                 ($signed(joya[15:8]) < -64) ? 4'd9  :
                 ($signed(joya[15:8]) < -32) ? 4'd11 :
                 ($signed(joya[15:8]) >  96) ? 4'd0  :
                 ($signed(joya[15:8]) >  64) ? 4'd4  :
                 ($signed(joya[15:8]) >  32) ? 4'd6  : 4'd7; 

reg j2 = 0;
always @(posedge clk_sys) begin
	if(joy2) j2 <= 1;
	if(joy1) j2 <= 0;
end

//////////////////////////////////////////////////////////////////

// DISPLAY
wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b,intensity;
wire [3:0] red,green,blue;
wire [7:0] ri,gi,bi;

assign ri = r*intensity;
assign gi = g*intensity;
assign bi = b*intensity;

assign red = ri[7:4];
assign blue = bi[7:4];
assign green = gi[7:4];

reg ce_pix;
always @(posedge clk_48) begin
	reg [2:0] div;
	div <= div + 1'd1;
	ce_pix <= !div;
end

arcade_video #(256,12,1) arcade_video
(
	.*,

	.clk_video(clk_48),

	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(~hs),
	.VSync(~vs),

	.fx(status[5:3])
);

wire [7:0] audio;
assign AUDIO_L = {audio, 6'd0};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

williams2 williams2
(
	.clock_12(clk_12),
	.reset(reset),

	.video_r(r),           // [3:0]
	.video_g(g),           // [3:0]
	.video_b(b),           // [3:0]
	.video_i(),            // [3:0] Color Intensity options
	.video_hblank(hblank), // 48 <-> 1
	.video_vblank(vblank), // 504 <-> 262
	.video_hs(hs),
	.video_vs(vs),

	.audio_out(audio), // [7:0]

	.BTN( {BTN[2:0],reset} ),
	.SW ( SW          ),
	.JA ( JA          ),
	.JB ( JB          ),

	// from DE10_lite
 	//.btn_advance          ( keys_HUA[0] ),
 	//.btn_auto_up          ( keys_HUA[1] ),
 	//.btn_high_score_reset ( keys_HUA[2] ),

 	//.btn_trigger_1  ( joyHBCPPFRLDU[4] ),
 	//.btn_trigger_2  ( joyHBCPPFRLDU[4] ),
 	//.btn_coin       ( joyHBCPPFRLDU[7] ),
 	//.btn_start_2    ( joyHBCPPFRLDU[6] ),
 	//.btn_start_1    ( joyHBCPPFRLDU[5] ),
 	//.btn_run_1      ( joyHBCPPFRLDU[3] & joyHBCPPFRLDU[1] & joyHBCPPFRLDU[2] & joyHBCPPFRLDU[0] ),
 	//.btn_run_2      ( joyHBCPPFRLDU[3] & joyHBCPPFRLDU[1] & joyHBCPPFRLDU[2] & joyHBCPPFRLDU[0] ),
 	//.btn_aim_1      ( joyHBCPPFRLDU[3] & joyHBCPPFRLDU[1] & joyHBCPPFRLDU[2] & joyHBCPPFRLDU[0] ), // aim should use separate controls
 	//.btn_aim_2      ( joyHBCPPFRLDU[3] & joyHBCPPFRLDU[1] & joyHBCPPFRLDU[2] & joyHBCPPFRLDU[0] ),

	.sw_coktail_table(),
	.seven_seg(),

	.dbg_out(),

	.dn_addr(ioctl_addr[17:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr && ioctl_index==0)
);

endmodule
