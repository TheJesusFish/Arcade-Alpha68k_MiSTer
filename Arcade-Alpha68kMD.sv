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

`default_nettype none

module emu
(
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
//assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;
assign FB_FORCE_BLANK = 0;

assign AUDIO_MIX = 0;
assign LED_USER =  | {cfg,dsw_sp85,dsw_m68k,coin_ratio_a,coin_ratio_b} ;// | { frame_count, global_count, rom_count, rom_2_count, sprite_count, sound_count, sprite_overrun, sp_count } ;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

assign m68k_a[0] = 0;

// declared ahead of use
wire        vert_game;
wire        hold68, holdz80, holdsnd;
wire [211:0] z80_reg;
wire        ss_hold68, ss_holdz80, ss_z80_run, ss_holdsnd, ss_cpu_execute, ss_irq, ss_reset68, ss_resetz80, ss_dirset, ss_mute, ss_active;
wire        ss_ovr_rd, ss_misc_wr;
wire [15:0] ss_ovr_data;
wire [79:0] ss_misc_out;
wire [211:0] ss_dir;
wire        ss_aux_en;
wire  [2:0] ss_aux_sel;
wire [13:0] ss_aux_addr;
wire [15:0] ss_aux_wdata;
wire  [1:0] ss_aux_we;
wire        ss_rp_opn, ss_rp_opll, ss_rp_wr, ss_rp_a0;
wire  [7:0] ss_rp_din;
wire        ss_save, ss_load, ss_status_set, ss_info_req;
wire  [1:0] ss_slot;
wire  [7:0] ss_info;
wire        hs_hold68, hs_aux_en, hs_present, hs_upload_req;
wire  [2:0] hs_aux_sel;
wire [13:0] hs_aux_addr;
wire [15:0] hs_aux_wdata;
wire  [1:0] hs_aux_we;
wire        ioctl_rd;

// Status Bit Map:
//              Upper Case                     Lower Case
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X   XXXXXX        XXXXX XXXXXXXX      XX

wire [1:0]  aspect_ratio = status[9:8];
wire        orientation = ~vert_game | status[3];   // 1 = landscape output
wire [2:0]  scan_lines = status[6:4];

wire [3:0]  hs_offset = status[27:24];
wire [3:0]  vs_offset = status[31:28];
wire [3:0]  hs_width  = status[59:56];
wire [3:0]  vs_width  = status[63:60];

wire kill_laugh = status[37];

assign VIDEO_ARX = (!aspect_ratio) ? (orientation  ? 8'd8 : 8'd7) : (aspect_ratio - 1'd1);
assign VIDEO_ARY = (!aspect_ratio) ? (orientation  ? 8'd7 : 8'd8) : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
    "Alpha68kMD;SS3E000000:400000;",
    "-;",
    "P1,Video Settings;",
    "P1-;",
    "P1O89,Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
    "H1P1O3,Orientation,Vert,Horz;",
    "P1-;",
    "P1O46,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%,CRT 100%;",
    "P1OA,Force Scandoubler,Off,On;",
    "P1-;",
    "P1O7,Video Mode,NTSC,PAL;",
    "P1-;",
    "P1OOR,H-sync Pos Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1OSV,V-sync Pos Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1-;",
    "P1oOR,H-sync Width Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1oSV,V-sync Width Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1-;",
    "P2,Pause Options;",
    "P2-;",
    "P2OK,Pause when OSD is open,Off,On;",
    "P2OL,Dim video after 10s,Off,On;",
    "-;",
    "P3,Debug Settings;",
    "P3-;",
    "P3OI,P1 Rotary Type,Gamepad,LS-30;",
    "P3OJ,P2 Rotary Type,Gamepad,LS-30;",
    "P3-;",
    "P3o6,Swap P1/P2 Joystick,Off,On;",
    "P3-;",
    "P3o5,GangWars Enemy Laugh,On,Off;",
    "P3-;",
    "-;",
    "O[66:65],Savestate Slot,1,2,3,4;",
    "O[64],Autoincrement Slot,Off,On;",
    "R[67],Save state (Alt-F1);",
    "R[68],Restore state (F1);",
    "-;",
    "H2O[69],Autosave Hiscores,On,Off;",
    "H2R[70],Save Hiscores;",
    "-;",
    "DIP;",
    "-;",
    "R0,Reset;",
    "I,",
    "Hold L: Up Load|Down Save|L/R Slot,",
    "Active Slot 1,",
    "Active Slot 2,",
    "Active Slot 3,",
    "Active Slot 4,",
    "Save to state 1,",
    "Restore state 1,",
    "Save to state 2,",
    "Restore state 2,",
    "Save to state 3,",
    "Restore state 3,",
    "Save to state 4,",
    "Restore state 4;",
    "v,1;",
    "V,v",`BUILD_DATE
};


wire hps_forced_scandoubler;
wire forced_scandoubler = hps_forced_scandoubler | status[10];

wire  [1:0] buttons;
wire [127:0] status;
wire [10:0] ps2_key;
wire [31:0] joy0_full, joy1_full, joy2_full, joy3_full;
wire [15:0] joy0 = joy0_full[15:0];
wire [15:0] joy1 = joy1_full[15:0];
wire [15:0] joy2 = joy2_full[15:0];
wire [15:0] joy3 = joy3_full[15:0];

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),

    .buttons(buttons),
    .ps2_key(ps2_key),
    .status(status),
    .status_in({status[127:67], ss_slot, status[64:0]}),
    .status_set(ss_status_set),
    .status_menumask({13'd0, ~hs_present, ~vert_game, direct_video}),
    .info_req(ss_info_req),
    .info(ss_info),
    .forced_scandoubler(hps_forced_scandoubler),
    .gamma_bus(gamma_bus),
    .direct_video(direct_video),
    .video_rotated(video_rotated),

    .ioctl_download(ioctl_download),
    .ioctl_upload(ioctl_upload),
    .ioctl_upload_req(hs_upload_req),
    .ioctl_upload_index(8'd4),
    .ioctl_wr(ioctl_wr),
    .ioctl_rd(ioctl_rd),
    .ioctl_addr(ioctl_addr_full),
    .ioctl_dout(ioctl_dout),
    .ioctl_din(ioctl_din),
    .ioctl_index(ioctl_index),
    .ioctl_wait(ioctl_wait),

    .joystick_0(joy0_full),
    .joystick_1(joy1_full),
    .joystick_2(joy2_full),
    .joystick_3(joy3_full)
);

// INPUT

// 8 dip switches of 8 bits
reg [7:0] sw[8];
always @(posedge clk_sys) begin
    if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) begin
        sw[ioctl_addr[2:0]] <= ioctl_dout;
    end
end

wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wait;
wire        ioctl_wr;
wire [15:0] ioctl_index;
wire [26:0] ioctl_addr_full;
wire [24:0] ioctl_addr = ioctl_addr_full[24:0];
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

reg   [3:0] pcb;
reg   [7:0] cfg;

localparam SKYADV      = 0;
localparam GANGWARS    = 1;
localparam SBASEBALJ   = 2;
localparam SBASEBAL    = 3;
localparam SKYADVU     = 4;

localparam SKYSOLDR    = 5;
localparam TIMESOLD    = 6;
localparam BATFIELD    = 7;

localparam GOLDMEDL    = 8;

reg [1:0] board_rev ;
reg [1:0] mcu_type  ;
reg       coin_type ;
reg       invert_in ;

//-- board config 6 bits
//        00 = II
//        01 = III
//        11 = V
//mcu id  00 = don't care
//        01 = 0x8814
//        10 = 0x8512
//        11 = 0x8713
//coin     0 = 0x2222 / 1 = 0x2423
//invert   0 = input not inverted / 1 = inverted

always @(posedge clk_sys) begin
    if (ioctl_wr && ioctl_index==1) begin
        if ( ioctl_addr == 0) begin
            pcb <= ioctl_dout;
        end else if (ioctl_addr == 1) begin
            board_rev <= ioctl_dout[5:4];
            mcu_type  <= ioctl_dout[3:2];
            coin_type <= ioctl_dout[1];
            invert_in <= ioctl_dout[0];
        end
    end
end

wire [21:0] gamma_bus;

// joystick bits: [4] button 1, [5] button 2, [6] start, [7] coin, [8] pause, [9] save state, [10] button 3, [11] rotate CW, [12] rotate CCW
wire [15:0] pad0 = joy0[9] ? 16'd0 : joy0;   // pad 1 is muted for the game while L (save state) is held
wire [15:0] pad1 = joy1;
wire [15:0] pad2 = joy2;
wire [15:0] pad3 = joy3;

// DIP switches seen by the game, taken while reset is held
reg  [7:0] sw0_l, sw1_l;
always @(posedge clk_sys) begin
    if ( reset ) begin
        sw0_l <= sw[0];
        sw1_l <= sw[1];
    end
end

reg [7:0] p1;
reg [7:0] p2;
reg [3:0] p3;
reg [3:0] p4;
reg [7:0] dsw_m68k;
reg [7:0] dsw_sp85;
reg [7:0] coin;
reg flip_dip ;


always @ (posedge clk_sys ) begin
    if ( pcb == GOLDMEDL ) begin
        // special case gold medal
        // controls are active low
        p1   <=  { start1, start3, p2_buttons[1], p1_buttons[1], p2_buttons[2], p2_buttons[0], p1_buttons[2], p1_buttons[0]} ;
        p2   <=  { start2, start4, p4_buttons[1], p3_buttons[1], p4_buttons[2], p4_buttons[0], p3_buttons[2], p3_buttons[0]} ;

        dsw_m68k <=  ~{sw0_l[7:2], ~key_test, ~key_service};
        dsw_sp85 <=   {sw1_l[7:0] };
    end else if ( invert_in == 0 ) begin
        // non inverted - active low
        p1   <=  ~{ start1, p1_buttons[2:0], p1_right, p1_left, p1_down, p1_up} ;
        p2   <=  ~{ start2, p2_buttons[2:0], p2_right, p2_left, p2_down, p2_up} ;

        if ( board_rev == 3 ) begin
            // Rev V
            dsw_m68k <=  {sw1_l[7:2], ~key_test, ~key_service};  // IN3
            dsw_sp85 <=  {sw0_l[7:0] };                          // IN4
        end else begin
            // Rev II & III
            dsw_m68k <=  {sw0_l[7:2], ~key_test, ~key_service};
            dsw_sp85 <=  {sw1_l[7:0] };
        end
    end else begin
        // inverted - active high
        p1   <=  { start1, p1_buttons[2:0], p1_right, p1_left, p1_down, p1_up} ;
        p2   <=  { start2, p2_buttons[2:0], p2_right, p2_left, p2_down, p2_up} ;

        if ( board_rev == 3 ) begin
            // Rev V
            dsw_m68k <=  ~{sw1_l[7:2], ~key_test, ~key_service};
            dsw_sp85 <=  sw0_l[7:0] ;
        end else begin
            // Rev II & III
            // TIMESOLD
            dsw_m68k <=  ~{sw0_l[7:2], ~key_test, ~key_service};
            dsw_sp85 <=  sw1_l[7:0] ;
        end
    end

    if ( board_rev == 0 ) begin
        flip_dip <= dsw_m68k[2] ;
    end else begin
        if ( pcb == SBASEBALJ || pcb == SBASEBAL ) begin
            // Super Champion Baseball: Flip Screen DIP is 68000 DSW bit 3
            flip_dip <= ~dsw_m68k[3];
        end else begin
            flip_dip <= ~dsw_sp85[4] ;
        end
    end

    if ( pcb == GOLDMEDL ) begin
        coin <=  { 2'b0, coin_b, coin_a, 2'b0, key_test, key_service } ;
    end else begin
        coin <=  ~{ 2'b0, coin_b, coin_a, 2'b0, ~key_test, ~key_service } ;
    end
end

reg         p1_right;
reg         p1_left;
reg         p1_down;
reg         p1_up;
reg  [2:0]  p1_buttons;

reg         p2_right;
reg         p2_left;
reg         p2_down;
reg         p2_up;
reg  [2:0]  p2_buttons;

reg         p3_right;
reg         p3_left;
reg         p3_down;
reg         p3_up;
reg  [2:0]  p3_buttons;

reg         p4_right;
reg         p4_left;
reg         p4_down;
reg         p4_up;
reg  [2:0]  p4_buttons;

wire [2:0]  pad0_buttons = { pad0[10], pad0[5], pad0[4] };
wire [2:0]  pad1_buttons = { pad1[10], pad1[5], pad1[4] };

always @ * begin
    p3_right   = 0;
    p3_left    = 0;
    p3_down    = 0;
    p3_up      = 0;
    p3_buttons = { pad2[10], pad2[5], pad2[4] };

    p4_right   = 0;
    p4_left    = 0;
    p4_down    = 0;
    p4_up      = 0;
    p4_buttons = { pad3[10], pad3[5], pad3[4] };

    if ( pcb == GOLDMEDL ) begin
        p1_right   = 0;
        p1_left    = 0;
        p1_down    = 0;
        p1_up      = 0;
        p1_buttons = pad0_buttons | {key_p1_c, key_p1_b, key_p1_a};

        p2_right   = 0;
        p2_left    = 0;
        p2_down    = 0;
        p2_up      = 0;
        p2_buttons = pad1_buttons | {key_p2_c, key_p2_b, key_p2_a};
    end else if ( status[38] == 0 ) begin
        p1_right   = pad0[0] | key_p1_right;
        p1_left    = pad0[1] | key_p1_left;
        p1_down    = pad0[2] | key_p1_down;
        p1_up      = pad0[3] | key_p1_up;
        p1_buttons = pad0_buttons | {key_p1_c, key_p1_b, key_p1_a};

        p2_right   = pad1[0] | key_p2_right;
        p2_left    = pad1[1] | key_p2_left;
        p2_down    = pad1[2] | key_p2_down;
        p2_up      = pad1[3] | key_p2_up;
        p2_buttons = pad1_buttons | {key_p2_c, key_p2_b, key_p2_a};
    end else begin
        p2_right   = pad0[0] | key_p1_right;
        p2_left    = pad0[1] | key_p1_left;
        p2_down    = pad0[2] | key_p1_down;
        p2_up      = pad0[3] | key_p1_up;
        p2_buttons = pad0_buttons | {key_p1_c, key_p1_b, key_p1_a};

        p1_right   = pad1[0] | key_p2_right;
        p1_left    = pad1[1] | key_p2_left;
        p1_down    = pad1[2] | key_p2_down;
        p1_up      = pad1[3] | key_p2_up;
        p1_buttons = pad1_buttons | {key_p2_c, key_p2_b, key_p2_a};
    end
end

// each controller drives its own player's start and coin
wire start1  = pad0[6] | key_start_1p;
wire start2  = pad1[6] | key_start_2p;
wire start3  = pad2[6] | key_start_3p;
wire start4  = pad3[6] | key_start_4p;
wire coin_a  = pad0[7] | key_coin_a;
wire coin_b  = pad1[7] | key_coin_b;
wire b_pause = joy0[8] | joy1[8] | key_pause;

// Keyboard handler

wire key_start_1p, key_start_2p, key_start_3p, key_start_4p, key_coin_a, key_coin_b;
wire key_tilt, key_test, key_reset, key_service, key_pause;
//wire key_fg_enable, key_spr_enable;

wire key_p1_up, key_p1_left, key_p1_down, key_p1_right, key_p1_a, key_p1_b, key_p1_c, key_p1_d;
wire key_p2_up, key_p2_left, key_p2_down, key_p2_right, key_p2_a, key_p2_b, key_p2_c, key_p2_d;

wire pressed = ps2_key[9];

reg [11:0] key_ls30_p1;
reg [11:0] key_ls30_p2;

always @(posedge clk_sys) begin
    reg old_state;

    old_state <= ps2_key[10];
    if(old_state ^ ps2_key[10]) begin
        casex(ps2_key[8:0])
            'h016: key_start_1p   <= pressed; // 1
            'h01e: key_start_2p   <= pressed; // 2
            'h02E: key_coin_a     <= pressed; // 5
            'h036: key_coin_b     <= pressed; // 6
            'h006: key_test       <= pressed; // f2
            'h004: key_reset      <= pressed; // f3
            'h046: key_service    <= pressed; // 9
            'h02c: key_tilt       <= pressed; // t
            'h04D: key_pause      <= pressed; // p

            9'h075, 9'h175: key_p1_up      <= pressed; // up
            9'h072, 9'h172: key_p1_down    <= pressed; // down
            9'h06b, 9'h16b: key_p1_left    <= pressed; // left
            9'h074, 9'h174: key_p1_right   <= pressed; // right
            'h014: key_p1_a       <= pressed; // lctrl
            'h011: key_p1_b       <= pressed; // lalt
            'h029: key_p1_c       <= pressed; // spacebar
            'h012: key_p1_d       <= pressed; // lshift

            'h02d: key_p2_up      <= pressed; // r
            'h02b: key_p2_down    <= pressed; // f
            'h023: key_p2_left    <= pressed; // d
            'h034: key_p2_right   <= pressed; // g
            'h01c: key_p2_a       <= pressed; // a
            'h01b: key_p2_b       <= pressed; // s
            'h015: key_p2_c       <= pressed; // q
            'h01d: key_p2_d       <= pressed; // w

            'h026: key_start_3p   <= pressed; // 3
            'h025: key_start_4p   <= pressed; // 4

            // Rotary1 LS-30 P1 Scancodes
            'h035: key_ls30_p1[0]  <= pressed; // y
            'h03c: key_ls30_p1[1]  <= pressed; // u
            'h043: key_ls30_p1[2]  <= pressed; // i
            'h044: key_ls30_p1[3]  <= pressed; // o
            'h033: key_ls30_p1[4]  <= pressed; // h
            'h03b: key_ls30_p1[5]  <= pressed; // j
            'h042: key_ls30_p1[6]  <= pressed; // k
            'h04b: key_ls30_p1[7]  <= pressed; // l
            'h031: key_ls30_p1[8]  <= pressed; // n
            'h03a: key_ls30_p1[9]  <= pressed; // m
            'h041: key_ls30_p1[10] <= pressed; // ,
            'h049: key_ls30_p1[11] <= pressed; // .

            // Rotary1 LS-30 P2 Scancodes
            'h01a: key_ls30_p2[0]  <= pressed; // z
            'h022: key_ls30_p2[1]  <= pressed; // x
            'h021: key_ls30_p2[2]  <= pressed; // c
            'h02a: key_ls30_p2[3]  <= pressed; // v
            'h032: key_ls30_p2[4]  <= pressed; // b
            'h058: key_ls30_p2[5]  <= pressed; // caps lock
            'h024: key_ls30_p2[6]  <= pressed; // e
            'h02c: key_ls30_p2[7]  <= pressed; // t
            'h026: key_ls30_p2[8]  <= pressed; // 3
            'h025: key_ls30_p2[9]  <= pressed; // 4
            'h03d: key_ls30_p2[10] <= pressed; // 7
            'h03e: key_ls30_p2[11] <= pressed; // 8

            //'h001: key_fg_enable  <= key_fg_enable  ^ pressed; // f9
            //'h009: key_spr_enable <= key_spr_enable ^ pressed; // f10
        endcase
    end
end

// Rotary controls

reg [11:0] rotary1 ;  // this needs to be set using status or keyboard
reg [11:0] rotary2 ;  // the active bit is low

reg last_rot1_cw ;
reg last_rot1_ccw ;
reg last_rot2_cw ;
reg last_rot2_ccw ;

wire p1_rotary_controller_type = status[18];
wire p2_rotary_controller_type = status[19];
wire p1_swap = status[38];

wire rot1_cw;
wire rot1_ccw;
wire rot2_cw;
wire rot2_ccw;

assign rot1_cw  = p1_swap ? (pad1[11] | key_ls30_p2[0]) : (pad0[11] | key_ls30_p1[0]);
assign rot1_ccw = p1_swap ? (pad1[12] | key_ls30_p2[1]) : (pad0[12] | key_ls30_p1[1]);
assign rot2_cw  = p1_swap ? (pad0[11] | key_ls30_p1[0]) : (pad1[11] | key_ls30_p2[0]);
assign rot2_ccw = p1_swap ? (pad0[12] | key_ls30_p1[1]) : (pad1[12] | key_ls30_p2[1]);

always @ (posedge clk_sys) begin

    if ( reset == 1 ) begin
        rotary1 <= 12'h800 ;
        rotary2 <= 12'h800 ;
    end else begin
        if ( p1_rotary_controller_type == 0 ) begin
            // did the button state change?
            if ( rot1_cw != last_rot1_cw ) begin
                last_rot1_cw <= rot1_cw;
                // rotate right
                if ( rot1_cw == 1 ) begin
                    rotary1 <= { rotary1[0], rotary1[11:1] };
                end
            end

            if ( rot1_ccw != last_rot1_ccw ) begin
                last_rot1_ccw <= rot1_ccw;
                // rotate left
                if ( rot1_ccw == 1 ) begin
                    rotary1 <= { rotary1[10:0], rotary1[11] };
                end
            end
        end else begin
            rotary1 <= key_ls30_p1;
        end

        if ( p2_rotary_controller_type == 0 ) begin
            if ( rot2_cw != last_rot2_cw ) begin
                last_rot2_cw <= rot2_cw;
                if ( rot2_cw == 1 ) begin
                    rotary2 <= { rotary2[0], rotary2[11:1] };
                end
            end

            if ( rot2_ccw != last_rot2_ccw ) begin
                last_rot2_ccw <= rot2_ccw;
                if ( rot2_ccw == 1 ) begin
                    rotary2 <= { rotary2[10:0], rotary2[11] };
                end
            end
        end else begin
            rotary2 <= key_ls30_p2;
        end

        if ( ss_misc_wr ) begin
            rotary1 <= ss_misc_out[59:48];
            rotary2 <= ss_misc_out[71:60];
        end
    end
end

reg user_flip;

wire pll_locked;

wire clk_sys;
reg  clk_3M,clk_4M,clk_6M,clk_20M,clk_io;

wire clk_72M;

pll pll
(
    .refclk(CLK_50M),
    .rst(0),
    .outclk_0(clk_sys),
    .outclk_1(clk_72M),
    .locked(pll_locked)
);

assign    SDRAM_CLK = clk_72M;

localparam  CLKSYS=72;

reg [15:0] clk20_count;
reg  [5:0] clk6_count;
reg  [7:0] clk4_count;
reg  [5:0] clk3_count;
reg [15:0] clk_upd_count;

reg [16:0] clk_io_count;

reg [15:0] frame_count;


always @ (posedge clk_sys) begin

    clk_3M <= ( clk3_count == 0 );

    if ( clk3_count == 23 ) begin // 17
        clk3_count <= 0;
    end else begin
        clk3_count <= clk3_count + 1;
    end

    // M=9 / N=181
    clk_4M <= 0;
    if ( clk4_count > 180 ) begin
        clk_4M <= 1;
        clk4_count <= clk4_count - 171;
    end else begin
        clk4_count <= clk4_count + 9;
    end

    clk_6M <= ( clk6_count == 0 );

    if ( clk6_count == 11 ) begin // 11
        clk6_count <= 0;
    end else begin
        clk6_count <= clk6_count + 1;
    end

    // fractional divider 20MHz from 72
    if ( hold68 ) begin
        clk_20M <= 0;
    end else begin
        if ( board_rev == 3 ) begin
            clk_20M <= 0;
            if ( clk20_count > 17 ) begin
                clk_20M <= 1 ;
                clk20_count <= clk20_count - 12;
            end else begin
                clk20_count <= clk20_count + 5;
            end
        end else begin
            // 18MHZ
            clk_20M <= ( clk20_count == 0 );
            if ( clk20_count == 3 ) begin
                clk20_count <= 0;
            end else begin
                clk20_count <= clk20_count + 1;
            end
        end
    end

    if ( !holdz80 ) begin
        clk_io <= ( clk_io_count == 0 ) ;

        if ( clk_io_count == 4_666_234 ) begin // 15.4 Hz
            clk_io_count <= 0;
        end else begin
            clk_io_count <= clk_io_count + 1;
        end
    end else begin
        clk_io <= 0;
    end

end

wire    rom_download = ioctl_download && (ioctl_index==0);

// a ROM load keeps the core in reset until the DIP switch download that follows it has ended
wire    dip_download = ioctl_download && (ioctl_index==254);
reg     dip_download_l, rom_dip_wait;
always @(posedge clk_sys) begin
    dip_download_l <= dip_download;
    if ( rom_download ) rom_dip_wait <= 1;
    else if ( dip_download_l && !dip_download ) rom_dip_wait <= 0;
end

wire    reset;
assign  reset = RESET | key_reset | status[0] | rom_download | rom_dip_wait ;

// freeze: pause, save state and hiscore restore
assign  hold68  = ( pause_cpu | ss_hold68 | hs_hold68 ) & ~ss_cpu_execute;
assign  holdz80 = ( pause_cpu & ~ss_z80_run ) | ss_holdz80;
assign  holdsnd = pause_cpu | ss_holdsnd;

//////////////////////////////////////////////////////////////////
assign vert_game = ( pcb == SKYADV ) || ( pcb == SKYADVU ) || ( pcb == SKYSOLDR ) || ( pcb == TIMESOLD ) || ( pcb == BATFIELD );
wire rotate_ccw = ( pcb == SKYSOLDR );
wire no_rotate = orientation | direct_video;
wire video_rotated ;
wire flip = 0;

reg [23:0]     rgb;

wire hbl;
wire vbl;

wire [8:0] hc;
wire [8:0] vc;

wire hsync;
wire vsync;

reg hbl_delay, vbl_delay;

always @ ( posedge clk_sys ) begin
    if ( ce_6m ) begin
        hbl_delay <= hbl ;
        vbl_delay <= vbl ;
    end
end

video_timing video_timing (
    .clk(clk_sys),
    .clk_pix(clk_6M),
    .pcb(pcb),
    .hc(hc),
    .vc(vc),
    .hs_offset(hs_offset),
    .vs_offset(vs_offset),
    .hs_width(hs_width),
    .vs_width(vs_width),
    .hbl(hbl),
    .vbl(vbl),
    .hsync(hsync),
    .vsync(vsync)
);

// PAUSE SYSTEM
wire    pause_cpu;
wire    hs_pause = 1'b0;

// 8 bits per colour, 72MHz sys clk
pause #(8,8,8,72) pause
(
    .clk_sys(clk_sys),
    .reset(reset),
    .user_button(b_pause),
    .pause_request(hs_pause),
    .options(status[21:20]),
    .pause_cpu(pause_cpu),
    .dim_video(dim_video),
    .OSD_STATUS(OSD_STATUS),
    .r(rgb[23:16]),
    .g(rgb[15:8]),
    .b(rgb[7:0]),
    .rgb_out(rgb_pause_out)
);

wire [23:0] rgb_pause_out;
wire dim_video;

// clk_sys enables high in the cycle before clk_20M / clk_6M rise
wire clk20_next = hold68 ? 1'b0 : ( board_rev == 3 ) ? ( clk20_count > 17 ) : ( clk20_count == 0 );
wire ce_20m     = clk20_next & ~clk_20M;
wire ce_6m      = ( clk6_count == 0 );

arcade_video #(256,24) arcade_video
(
        .*,

        .clk_video(clk_sys),
        .ce_pix(clk_6M),

        .RGB_in(rgb_pause_out),

        .HBlank(hbl_delay),
        .VBlank(vbl_delay),
        .HSync(hsync),
        .VSync(vsync),

        .fx(scan_lines)
);

// DDRAM: save states (port a, while frozen) and the rotation framebuffer (port b)
ddr_if ddr_host(), ddr_ss(), ddr_rot();

ddr_mux ddr_mux (
    .clk(clk_sys),
    .x(ddr_host),
    .a(ddr_ss),
    .b(ddr_rot)
);

assign DDRAM_CLK         = clk_sys;
assign DDRAM_ADDR        = ddr_host.addr[31:3];
assign DDRAM_BURSTCNT    = ddr_host.burstcnt;
assign DDRAM_DIN         = ddr_host.wdata;
assign DDRAM_BE          = ddr_host.byteenable;
assign DDRAM_WE          = ddr_host.write;
assign DDRAM_RD          = ddr_host.read;
assign ddr_host.rdata    = DDRAM_DOUT;
assign ddr_host.rdata_ready = DDRAM_DOUT_READY;
assign ddr_host.busy     = DDRAM_BUSY;

wire [28:0] rot_ddr_addr;
assign ddr_rot.addr      = { rot_ddr_addr, 3'b000 };
assign ddr_rot.acquire   = ~ddr_ss.acquire;

screen_rotate screen_rotate (
    .*,
    .DDRAM_CLK(),
    .DDRAM_BUSY(ddr_rot.busy),
    .DDRAM_BURSTCNT(ddr_rot.burstcnt),
    .DDRAM_ADDR(rot_ddr_addr),
    .DDRAM_DIN(ddr_rot.wdata),
    .DDRAM_BE(ddr_rot.byteenable),
    .DDRAM_WE(ddr_rot.write),
    .DDRAM_RD(ddr_rot.read)
);

reg [7:0] hc_del;

reg [4:0] tile_state;
reg [4:0] sprite_state;
reg [8:0] sprite_num;

reg   [2:0] pri_buf[0:255];

reg  [31:0] pix_data;
reg  [31:0] spr_pix_data;
reg  [31:0] spr_pix_data_fifo;

reg   [8:0] x;

wire  [8:0] sp_x    = x ;
wire  [8:0] sp_y    = vc ^ { 8 { flip_dip } };

wire  [9:0] fg_tile = { sp_x[7:3], sp_y[7:3] };

reg   [7:0] fg_colour;

reg   [7:0] sprite_colour;
reg  [14:0] sprite_tile_num;
reg         sprite_flip_x;
reg         sprite_flip_y;
reg   [1:0] sprite_group;
reg   [4:0] sprite_col;
reg  [15:0] sprite_col_x;
reg  [15:0] sprite_col_y;
//reg   [1:0] sprite_col_adj;
reg   [8:0] sprite_col_idx;
reg   [8:0] spr_x_pos;
reg   [3:0] spr_x_ofs;

reg   [1:0] sprite_layer;
wire  [1:0] layer_order [3:0] = '{2'd2,2'd3,2'd1,2'd0};

wire  [3:0] spr_pen = { spr_pix_data[24 + { 3 { sprite_flip_x } } ^ spr_x_ofs[2:0]],
                        spr_pix_data[16 + { 3 { sprite_flip_x } } ^ spr_x_ofs[2:0]],
                        spr_pix_data[ 8 + { 3 { sprite_flip_x } } ^ spr_x_ofs[2:0]],
                        spr_pix_data[ 0 + { 3 { sprite_flip_x } } ^ spr_x_ofs[2:0]] }  ;

//-- board config 6 bits
//        00 = II
//        01 = III
//        11 = V
//mcu id  00 = don't care
//        01 = 0x8814
//        10 = 0x8512
//        11 = 0x8713
//coin     0 = 0x2222 / 1 = 0x2423
//invert   0 = input not inverted / 1 = inverted

reg [7:0] config_bits ; // [8:0] = '{ 8'h30, 8'h30, 8'h30, 8'h30, 8'h00, 8'h00, 8'h04, 8'h22 };

reg   [11:0] sp_count ;

always @ (posedge clk_sys) begin
    if ( reset == 1 ) begin
        tile_state   <= 0;
        sprite_state <= 0;
        sprite_overrun <= 0;
        sprite_rom_cs <= 0;
        fg_colour <= 0;
    end else begin

        // tiles
        if ( tile_state == 0 && hc == 0 ) begin
            tile_state <= 1;
            sp_count <= 0;
            x <= 0;
        end else if ( tile_state == 1) begin
            line_buf_fg_w <= 0;
            fg_ram_addr <= { fg_tile, 1'b0 } ;
            tile_state <= 2;
        end else if ( tile_state == 2) begin
            // address is valid - need more more cycle to read
            fg_ram_addr <= fg_ram_addr + 1;
            tile_state <= 3;
        end else if ( tile_state == 3) begin
            // [15:0] fg_rom_addr
            if ( board_rev == 3 ) begin
                fg_rom_addr <= { tile_bank[2:0], fg_ram_dout[7:0], ~sp_x[2], sp_x[1], sp_y[2:0] } ;
            end else begin
                fg_rom_addr <= { tile_bank[6:4], fg_ram_dout[7:0], ~sp_x[2], sp_y[2:0], 1'b0 } ;
            end
            tile_state <= 4;
        end else if ( tile_state == 4) begin
            // address is valid - need more more cycle to read
            fg_rom_addr <= fg_rom_addr + 1;
            // the colour in the second tile attribute byte
            fg_colour <= fg_ram_dout[4:0] ; // [4] == opaque
            tile_state <= 5;
        end else if ( tile_state == 5) begin
            // version II boards need 16 bits.
            pix_data[7:0] <= fg_rom_data;
            tile_state <= 6 ;
        end else if ( tile_state == 6) begin
            pix_data[15:8] <= fg_rom_data;
            tile_state <= 7 ;
        end else if ( tile_state == 7) begin
            line_buf_addr_w <= { vc[0], x[8:0] };
            line_buf_fg_w <= 1;
            if ( board_rev == 3 ) begin
                case ( sp_x[0] )
                    0: line_buf_fg_din <= { fg_colour, pix_data[3:0] } ;
                    1: line_buf_fg_din <= { fg_colour, pix_data[7:4] } ;
                endcase
            end else begin
                case ( sp_x[1:0] )
                    0: line_buf_fg_din <= { fg_colour, pix_data[4], pix_data[0], pix_data[12], pix_data[8]  } ;
                    1: line_buf_fg_din <= { fg_colour, pix_data[5], pix_data[1], pix_data[13], pix_data[9]  } ;
                    2: line_buf_fg_din <= { fg_colour, pix_data[6], pix_data[2], pix_data[14], pix_data[10] } ;
                    3: line_buf_fg_din <= { fg_colour, pix_data[7], pix_data[3], pix_data[15], pix_data[11] } ;
                endcase
            end
            if ( x < 256 ) begin
                if ( sp_x[0] == 1'b1 ) begin
                    tile_state <= 1;
                end
                x <= x + 1;
            end else begin
                tile_state <= 8;
                line_buf_fg_w <= 0;
            end
        end else if ( tile_state == 8) begin
            x <= 0;
            tile_state <= 0;
        end

        // sprites. -- need 3 sprite layers - 1 layer is split
        if ( sprite_state == 0 && hc == 0 ) begin
            // init
            sprite_state <= 21; // 21 = clear buffer, 22 = don't   ***********
            sprite_num <= 0;
            sprite_layer <= 0;
            // setup clearing line buffer
            spr_buf_din <= 0 ;
            spr_x_pos <= 0;
        end else if ( sprite_state == 21 )  begin
            spr_buf_w <= 1 ;
            spr_buf_addr_w <= { vc[0], spr_x_pos };
            if ( spr_x_pos > 256 ) begin
                spr_buf_w <= 0 ;
                sprite_state <= 22;
            end
            spr_x_pos <= spr_x_pos + 1;
        end else if ( sprite_state == 22 ) begin
            // start
            case ( sprite_layer )
                0: begin
                        sprite_group <= 1;
                        sprite_col   <= 31;
                   end
                1: begin
                        sprite_group <= 2;
                        sprite_col   <= 0;
                   end
                2: begin
                        sprite_group <= 3;
                        sprite_col   <= 0;
                   end
                3: begin
                        sprite_group <= 1;
                        sprite_col   <= 0;
                   end
            endcase
            sprite_state <= 1;
        end else if ( sprite_state == 1 )  begin
            sp_count <= sp_count + 1;
            spr_buf_w <= 0 ;

            // setup x read
            sprite_ram_addr <= { sprite_col, 3'b0, sprite_group, 1'b0 } ;
            sprite_state <= 2;
        end else if ( sprite_state == 2 )  begin
            // setup y read
            sprite_ram_addr <= sprite_ram_addr + 1 ;
            sprite_state <= 3;
        end else if ( sprite_state == 3 )  begin
            // x valid
            sprite_col_x <= sprite_ram_dout;
            sprite_state <= 4;
        end else if ( sprite_state == 4 )  begin
            if ( sprite_col_x[7:0] > 128 ) begin
                sprite_state <= 17;
            end
            // y valid

            sprite_col_y <= sprite_ram_dout ;
            sprite_state <= 18;
        end else if ( sprite_state == 18 )  begin
            if ( sprite_layer == 0 ) begin
                if ( flip_dip == 0 ) begin
                    sprite_col_y <= sprite_col_y - 1 ;
                end else begin
                    sprite_col_y <= sprite_col_y + 1 ;
                end
            end
            sprite_state <= 5;
        end else if ( sprite_state == 5 )  begin
            // tile ofset from the top of the column
            sprite_col_idx <= sp_y + sprite_col_y[8:0] ;
            sprite_state <= 6;
        end else if ( sprite_state == 6 )  begin
            // setup sprite tile colour read
            sprite_ram_addr <= { sprite_group[1:0], sprite_col[4:0], sprite_col_idx[8:4], 1'b0 };
            sprite_state <= 7;

        end else if ( sprite_state == 7 ) begin
            // setup sprite tile index read
            sprite_ram_addr <= sprite_ram_addr + 1 ;
            sprite_state <= 8;
        end else if ( sprite_state == 8 ) begin
            // tile colour ready
            if ( board_rev == 3 ) begin
                sprite_colour <= sprite_ram_dout[7:0] ; // 0xff
            end else begin
                sprite_colour <= sprite_ram_dout[6:0] ; // 0x7f
            end
            sprite_state <= 9;
        end else if ( sprite_state == 9 ) begin
            // tile index ready
            if ( pcb == SKYADV || pcb == SKYADVU ) begin
                sprite_flip_x   <= 1'b0;
                sprite_flip_y   <= sprite_ram_dout[15] ;
                sprite_tile_num <= sprite_ram_dout[14:0] ;
            end else if (  pcb == GANGWARS ) begin
                sprite_flip_x   <= sprite_ram_dout[15] ;
                sprite_flip_y   <= 1'b0;  // 0x8000
                sprite_tile_num <= sprite_ram_dout[14:0] ;
            end else begin
                sprite_flip_x   <= sprite_ram_dout[14] ;
                sprite_flip_y   <= sprite_ram_dout[15] ;
                sprite_tile_num <= sprite_ram_dout[13:0] ;
            end
            spr_x_ofs <= 0;
            spr_x_pos <= { sprite_col_x[7:0], sprite_col_y[15] } ;
            sprite_state <= 10;
        end else if ( sprite_state == 10 )  begin
            case ( sprite_flip_y )
                1'b0: sprite_rom_addr <= { sprite_tile_num, ~sprite_flip_x,  sprite_col_idx[3:0] } ; // ~(sprite_flip_x^spr_x_ofs[3])
                1'b1: sprite_rom_addr <= { sprite_tile_num, ~sprite_flip_x, ~sprite_col_idx[3:0] } ;
            endcase

            sprite_rom_cs <= 1;
            sprite_state <= 11;
        end else if ( sprite_state == 11 ) begin
            // wait for sprite bitmap data
            if ( sprite_rom_valid == 1 ) begin
                sprite_rom_cs <= 0;
                spr_pix_data <= sprite_rom_data;
                spr_pix_data_fifo <= 0;             // debugging
                sprite_state <= 12 ;
            end
        end else if ( sprite_state == 12 ) begin
            case ( sprite_flip_y )
                1'b0: sprite_rom_addr <= { sprite_tile_num, sprite_flip_x,  sprite_col_idx[3:0] } ; // ~(sprite_flip_x^spr_x_ofs[3])
                1'b1: sprite_rom_addr <= { sprite_tile_num, sprite_flip_x, ~sprite_col_idx[3:0] } ;
            endcase

            sprite_rom_cs <= 1;

            sprite_state <= 13;
        end else if ( sprite_state == 13 ) begin
            // if the second read is ready queue the result and release sdram
            if ( sprite_rom_cs == 1 && sprite_rom_valid == 1 ) begin
                sprite_rom_cs <= 0;
                spr_pix_data_fifo <= sprite_rom_data;

            end else if ( sprite_rom_cs == 0 || spr_x_ofs < 7 ) begin
                //
                spr_buf_addr_w <= { vc[0], spr_x_pos };

                spr_buf_w <= (| spr_pen ) ; // don't write if 0 - transparent

                spr_buf_din <= { sprite_colour, spr_pen };

                if ( spr_x_ofs < 15 ) begin
                    spr_x_ofs <= spr_x_ofs + 1;
                    spr_x_pos <= spr_x_pos + 1;

                    // the second 8 pixel needs another rom read
                    if ( spr_x_ofs == 7 ) begin
                        spr_pix_data <= spr_pix_data_fifo ;
                    end

                end else begin
                    sprite_state <= 17;
                end
            end

        end else if ( sprite_state == 17) begin
            spr_buf_w <= 0 ;
            if ( hc < 340 ) begin
                if ( sprite_col < 30 || (sprite_col < 31 && sprite_layer < 3) ) begin
                    sprite_col <= sprite_col + 1;
                    sprite_state <= 1;
                end else begin
                    if ( sprite_layer < 3 ) begin
                        sprite_layer <= sprite_layer + 1;
                        sprite_state <= 22;
                    end else begin
                        sprite_state <= 0;
                    end
                end
            end else begin
                sprite_state <= 0;
            end
        end

    end
end

reg sprite_overrun;

reg [11:0] fg;
reg [11:0] sp;

reg [23:0] rgb_fg;
reg [23:0] rgb_sp;

reg [11:0] pen;
reg pen_valid;


// resistor dac 220, 470, 1k, 2.2k, 3.9k / has 8.2k pulldown for dimming (2nd block of 16)
wire [7:0] dac_weight[0:63] = '{8'd0,8'd13,8'd22,8'd34,8'd46,8'd57,8'd65,8'd75,8'd91,8'd100,8'd107,8'd116,8'd126,8'd134,8'd140,8'd148,
                                8'd168,8'd175,8'd180,8'd187,8'd194,8'd200,8'd205,8'd211,8'd220,8'd226,8'd230,8'd235,8'd241,8'd246,8'd250,8'd255,
                                // dim
                                8'd0, 8'd7,8'd17,8'd28,8'd41,8'd52,8'd60,8'd71,8'd87,8'd96,8'd103,8'd112,8'd122,8'd130,8'd136,8'd144,
                                8'd165,8'd172,8'd177,8'd184,8'd191,8'd197,8'd202,8'd208,8'd218,8'd223,8'd227,8'd233,8'd239,8'd244,8'd248,8'd253};


reg [5:0] r_pal ;
reg [5:0] g_pal ;
reg [5:0] b_pal ;

always @ (posedge clk_sys) begin

    tile_pal_wr <= 0;

    if ( hc < 257 ) begin
        if ( clk6_count == 2 ) begin
            line_buf_addr_r <= { ~vc[0], 1'b0, hc[7:0] ^ { 8 { flip_dip } } } ;
        end else if ( clk6_count == 3 ) begin
            fg <= line_buf_fg_out[11:0] ;
            sp <= spr_buf_dout[11:0] ;
        end else if ( clk6_count == 4 ) begin
            pen <= ( { fg[8], fg[3:0] } == 0 ) ? sp[11:0] : { 3'b0, fg[7:0] };  //   fg[8] == 1 means tile is opaque
            //pen <= sp[11:0] ;
        end else if ( clk6_count == 5 ) begin
            if ( pen[3:0] == 0 ) begin
                if ( board_rev == 3 ) begin
                    tile_pal_addr <= 12'hfff ; // background pen
                end else begin
                    tile_pal_addr <= 12'h7ff ; // background pen
                end
            end else begin
                tile_pal_addr <= pen[11:0] ;
            end
        end else if ( clk6_count == 7 ) begin
            r_pal <= { tile_pal_dout[15], tile_pal_dout[11:8] , tile_pal_dout[14] };
            g_pal <= { tile_pal_dout[15], tile_pal_dout[7:4]  , tile_pal_dout[13] };
            b_pal <= { tile_pal_dout[15], tile_pal_dout[3:0]  , tile_pal_dout[12] };
        end else if ( clk6_count == 8 ) begin
            rgb <= {dac_weight[r_pal], dac_weight[g_pal], dac_weight[b_pal] };
        end
    end
end

reg [7:0] tile_bank;
reg [1:0] vbl_sr;
reg [1:0] hbl_sr;

reg [7:0] credits;
reg [3:0] coin_count;
reg [1:0] coin_latch;

// Coin tables for games with MCU id 2222

// Time Soldiers, Sky Soldiers
reg [7:0] coin_ratio_a_II [0:7] = '{ 8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h13, 8'h22 };  // (#coins-1) / credits
reg [7:0] coin_ratio_b_II [0:7] = '{ 8'h01, 8'h11, 8'h21, 8'h31, 8'h41, 8'h51, 8'h61, 8'h71 };  // (#coins-1) / credits

// Sky Adventure
reg [7:0] coin_ratio_a_V [0:7] = '{ 8'h01, 8'h05, 8'h03, 8'h13, 8'h02, 8'h06, 8'h04, 8'h22 };  // (#coins-1) / credits
reg [7:0] coin_ratio_b_V [0:7] = '{ 8'h01, 8'h41, 8'h21, 8'h61, 8'h11, 8'h51, 8'h31, 8'h71 };  // (#coins-1) / credits

wire [7:0] coin_ratio_a = (board_rev != 3) ? coin_ratio_a_II[~dsw_sp85[2:0]] : coin_ratio_a_V[~dsw_sp85[3:1]];
wire [7:0] coin_ratio_b = (board_rev != 3) ? coin_ratio_b_II[~dsw_sp85[2:0]] : coin_ratio_b_V[~dsw_sp85[3:1]];

reg [12:0]  mcu_addr;
reg  [7:0]  mcu_din;
reg  [7:0]  mcu_dout;
reg         mcu_wh;
reg         mcu_wl;

reg         mcu_busy;
reg         mcu_2nd_write;
reg [12:0]  mcu_2nd_addr;
reg  [7:0]  mcu_2nd_din;
reg         mcu_2nd_wh;
reg         mcu_2nd_wl;

/// 68k cpu
always @ (posedge clk_sys) begin

    if ( reset == 1 ) begin
        m68k_dtack_n <= 1;

        m68k_ipl0_n <= 1 ;
        m68k_ipl1_n <= 1 ;

        z80_irq_n <= 1 ;
        m68k_latch <= 0;
        tile_bank <= 0;
        frame_count <= 0;

        mcu_addr <= 0;
        mcu_din <= 0 ;
        mcu_wh <= 0;
        mcu_wl <= 0;

        z80_latch <= 0;
        z80_nmi_n <= 1 ;
        z80_bank <= 0;
        z80_nmi_suppress <= 1; // ym2203 port high impedance on reset?

        credits <= 0;
        coin_latch <= 0;
        mcu_2nd_write <= 0;
        mcu_2nd_wl <= 0;
        mcu_2nd_wh <= 0;
        mcu_busy <= 0;
    end else begin

        // vblank handling
        vbl_sr <= { vbl_sr[0], vbl };
        if ( vbl_sr == 2'b01 ) begin // rising edge
            //  68k vbl interrupt
            m68k_ipl0_n <= 0;
            frame_count <= frame_count + 1;
        end

        // mcu interrupt handling
        hbl_sr <= { hbl_sr[0], clk_io };  // ????
        if ( hbl_sr == 2'b01 ) begin // rising edge
            //  68k vbl interrupt
            m68k_ipl1_n <= 0;
        end

        if ( clk_20M == 1 ) begin
            // cpu acknowledged the interrupt
            // TODO - this should be enable lines set by reading memory locations d8000 & e0000
            if ( ( m68k_as_n == 0 ) && ( m68k_fc == 3'b111 ) && !( ss_active && m68k_a[3:1] == 3'b111 ) ) begin
                m68k_ipl0_n <= 1;
                m68k_ipl1_n <= 1;
            end

            mcu_wh <= 0;
            mcu_wl <= 0;

            // tell 68k to wait for valid data. 0=ready 1=wait
            // always ack when it's not program rom
            m68k_dtack_n <= m68k_rom_cs ? !m68k_rom_valid :
                            m68k_rom_2_cs ? !m68k_rom_2_valid :
                            0;

            if ( m68k_rw == 1 ) begin
                // reads
                m68k_din <=  ss_ovr_rd ? ss_ovr_data :
                             m68k_rom_cs ? m68k_rom_data :
                             m68k_ram_cs  ? m68k_ram_dout :
                             m68k_rom_2_cs ? m68k_rom_2_data :
                             // high byte of even addressed sprite ram not connected.  pull high.
                             m68k_spr_cs  ? m68k_sprite_dout : // 0xff000000
                             m68k_fg_ram_cs ? m68k_fg_ram_dout :
                             m68k_pal_cs ? m68k_pal_dout :
                             input_p1_cs ? { p2, p1 } :
                             m68k_dsw_cs ? { rotary1[7:0], dsw_m68k[7:0] } :
                             m68k_sp85_cs ? 0 :
                             m68k_rotary2_cs ? { rotary2[7:0], 8'h0 } :
                             m68k_rotary_msb_cs ? { rotary2[11:8], rotary1[11:8], 8'h0 } :
                             16'h0000;

                // mcu addresses are word
                if ( m68k_sp85_cs == 1 ) begin
                    if (  mcu_busy == 0 ) begin
                        mcu_busy <= 1;
                        if ( m68k_a[8:1] == 8'h00 ) begin

                            mcu_addr <= m68k_a[13:1];
                            mcu_din <= dsw_sp85[7:0] ;
                            mcu_wl <= 1;
                        end else if ( m68k_a[8:1] == 8'h22 ) begin

                            mcu_addr <= m68k_a[13:1];
                            mcu_din <= credits ;
                            credits <= 0;
                            mcu_wl <= 1;
                        end else if ( m68k_a[8:1] == 8'h29 ) begin

                            // coins
                            if ( { coin_b, coin_a } == 0 ) begin
                                coin_latch <= 0;

                                mcu_addr <= m68k_a[13:1];
                                mcu_din <= 8'h00 ;
                                mcu_wl <= 1;
                            end else if ( coin_latch == 0 ) begin
                                coin_latch <= { coin_b, coin_a };
                                // set coin id
                                if ( coin_type == 1 ) begin
                                    if ( coin_a == 1 ) begin
                                        mcu_din <= 8'h23 ;
                                    end else begin
                                        mcu_din <= 8'h24 ;
                                    end
                                end else begin
                                    mcu_din <= 8'h22 ;
                                    // only games with coin id 22 needs a coin counter
                                    if ( coin_a == 1 ) begin
                                        // calc before or after invert?
                                        if ( coin_ratio_a[7:4] == coin_count ) begin
                                            credits <= coin_ratio_a[3:0];
                                            coin_count <= 0;
                                        end else begin
                                            coin_count <= coin_count + 1;
                                        end
                                    end if ( coin_b == 1 ) begin
                                        if ( coin_ratio_b[7:4] == coin_count ) begin
                                            credits <= coin_ratio_b[3:0];
                                            coin_count <= 0;
                                        end else begin
                                            coin_count <= coin_count + 1;
                                        end
                                    end

                                    // clear for sky adv
                                    mcu_2nd_write <= 1;
                                    mcu_2nd_addr  <= m68k_a[13:1] - 7 ;
                                    mcu_2nd_din   <= 0 ;
                                    mcu_2nd_wl    <= 1;
                                end
                                mcu_addr <= m68k_a[13:1];
                                mcu_wl <= 1;
                            end else begin
                                mcu_addr <= m68k_a[13:1];
                                mcu_din <= 8'h00 ;
                                mcu_wl <= 1;
                            end

                            // if gang wars trigger writing the dip value to ram
                            if ( pcb == GANGWARS ) begin
                                mcu_2nd_write <= 1;
                                mcu_2nd_addr  <= 13'h0163 ;
                                mcu_2nd_din   <= dsw_sp85[7:0] ;
                                mcu_2nd_wh    <= 1;
                            end
                        end else if ( m68k_a[8:1] == 8'hfe ) begin
                            // mcu id hign - gang wars 8512
                            mcu_addr <= m68k_a[13:1];
                            mcu_wl <= 0;
                            if ( mcu_type == 2'b01 ) begin
                                mcu_din <= 8'h88 ;
                                mcu_wl <= 1;
                            end else if ( mcu_type == 2'b10 ) begin
                                mcu_din <= 8'h85 ;
                                mcu_wl <= 1;
                            end else if ( mcu_type == 2'b11 ) begin
                                mcu_din <= 8'h87 ;
                                mcu_wl <= 1;
                            end
                        end else if ( m68k_a[8:1] == 8'hff ) begin
                            // mcu id low
                            mcu_addr <= m68k_a[13:1];
                            mcu_wl <= 0;
                            if ( mcu_type == 2'b01 ) begin
                                mcu_din <= 8'h14 ;
                                mcu_wl <= 1;
                            end else if ( mcu_type == 2'b10 ) begin
                                mcu_din <= 8'h12 ;
                                mcu_wl <= 1;
                            end else if ( mcu_type == 2'b11 ) begin
                                mcu_din <= 8'h13 ;
                                mcu_wl <= 1;
                            end
                        end
                    end
                end else begin
                    mcu_busy <= 0;
                end

                if ( mcu_wl == 1 && mcu_2nd_write == 1 ) begin
                    mcu_addr <= mcu_2nd_addr;
                    mcu_din <= mcu_2nd_din ;
                    mcu_wl <= mcu_2nd_wl;
                    mcu_wh <= mcu_2nd_wh;

                    mcu_2nd_write <= 0;
                    mcu_2nd_wl <= 0;
                    mcu_2nd_wh <= 0;
                end

                if ( vbl_int_clr_cs == 1 ) begin
                    m68k_ipl0_n <= 1;
                end

                if ( cpu_int_clr_cs == 1 ) begin
                    m68k_ipl1_n <= 1;
                end

            end else begin
                // writes

                if ( m68k_latch_cs == 1 ) begin
                    // text tile banking
                    if ( m68k_uds_n == 0 && board_rev == 3) begin // UDS 0x80000 only Rev V
                        tile_bank <= m68k_dout[11:8] ;
                    end
                    if ( m68k_lds_n == 0 ) begin // LDS 0x80001
                        m68k_latch <= m68k_dout[7:0];
                    end
                end

                if ( m68k_lds_n == 0 && m68k_dsw_cs == 1 ) begin // LDS 0xc00xx
                    if  ( board_rev != 3 ) begin
                        tile_bank[m68k_a[5:3]] <= m68k_a[6] ;  //
                    end
                end

            end
        end

        if ( clk_6M && !holdz80 ) begin

            z80_wait_n <= 1;

            if ( z80_rd_n == 0 ) begin
                // Z80 READ
                if ( z80_banked_cs == 1 ) begin
                    if ( z80_banked_valid ) begin
                        z80_din <= z80_banked_data;
                    end else begin
                        z80_wait_n <= 0;
                    end
                end else if ( z80_ram_cs == 1 ) begin
                    z80_din <= z80_ram_data ;
                end else if ( z80_rom_cs == 1 ) begin
                    z80_din <= z80_rom_data ;
                end else if ( z80_latch_cs == 1 ) begin
                    z80_din <= ( kill_laugh == 1 && m68k_latch == 8'h81 ) ? 8'h00 : m68k_latch ;
                end
            end

            // WRITE

            opn_wr <= 0 ;

            // DAC
            if ( z80_dac_cs == 1 ) begin
                dac <= z80_dout ;
            end

            // OPLL YM2413
            if ( z80_ym2413_cs == 1 ) begin
                opll_data  <= z80_dout;

                opll_addr <= z80_addr[0] ;
            end

            // OPN YM2203
            if ( z80_ym2203_cs == 1 ) begin
                // write to io port A
                if ( z80_addr[0] == 0 ) begin
                    io_port_a_wr <= ( z80_dout == 8'h0e );
                end else begin
                    if ( io_port_a_wr == 1 ) begin
                        z80_nmi_suppress <= z80_dout[0];
                        io_port_a_wr <= 0;
                    end
                end
            end

            if ( z80_latch_clr_cs == 1 ) begin
                m68k_latch <= 0 ;
            end

            if ( z80_bank_set_cs == 1 ) begin
                 z80_bank <= z80_dout[4:0];
            end

        end

        // ym2203 can disable z80 nmi by writting 1 to bit 0 of portA
        // if enabled, nmi is triggered by falling edge of bit 0 vertical line count
        // /NMI is negative edge triggered
        z80_nmi_n <= (~vc[0]) | z80_nmi_suppress ;

        // save state restore of the core registers
        if ( ss_misc_wr ) begin
            m68k_latch       <= ss_misc_out[7:0];
            tile_bank        <= ss_misc_out[15:8];
            z80_bank         <= ss_misc_out[20:16];
            z80_nmi_suppress <= ss_misc_out[21];
            io_port_a_wr     <= ss_misc_out[22];
            credits          <= ss_misc_out[30:23];
            coin_latch       <= ss_misc_out[32:31];
            coin_count       <= ss_misc_out[36:33];
            mcu_busy         <= ss_misc_out[37];
            dac              <= ss_misc_out[45:38];
            m68k_ipl0_n      <= ss_misc_out[46];
            m68k_ipl1_n      <= ss_misc_out[47];
        end

    end
end

// core registers in the save state (80 bits)
wire [79:0] ss_misc_in = { 8'd0, rotary2, rotary1, m68k_ipl1_n, m68k_ipl0_n, dac, mcu_busy, coin_count, coin_latch, credits,
                           io_port_a_wr, z80_nmi_suppress, z80_bank, tile_bank, m68k_latch };


wire    m68k_rom_cs;
wire    m68k_rom_2_cs;
wire    m68k_ram_cs;
wire    m68k_pal_cs;
wire    m68k_spr_cs;
wire    m68k_fg_ram_cs;
wire    m68k_spr_flip_cs;
wire    input_p1_cs;
wire    m68k_rotary2_cs;
wire    m68k_rotary_msb_cs;
wire    m68k_dsw_cs;
wire    irq_z80_cs;
wire    m68k_latch_cs;
wire    z80_latch_read_cs;
wire    vbl_int_clr_cs;
wire    cpu_int_clr_cs;
wire    watchdog_clr_cs;
wire    m68k_sp85_cs;

wire    z80_rom_cs;
wire    z80_ram_cs;
wire    z80_banked_cs;

wire    z80_latch_cs;
wire    z80_latch_clr_cs;
wire    z80_dac_cs;
wire    z80_ym2413_cs;
wire    z80_ym2203_cs;
wire    z80_bank_set_cs;

chip_select cs (
    .clk(clk_sys),
    .pcb(pcb),

    // 68k bus
    .m68k_a,
    .m68k_as_n,
    .m68k_rw,

    .z80_addr,
    .MREQ_n,
    .IORQ_n,
    .RD_n( z80_rd_n ),
    .WR_n( z80_wr_n ),

    .M1_n,

    // 68k chip selects
    .m68k_rom_cs,
    .m68k_rom_2_cs,
    .m68k_ram_cs,
    .m68k_spr_cs,
    .m68k_sp85_cs,
    .m68k_fg_ram_cs,
    .m68k_pal_cs,

    .m68k_rotary2_cs,
    .m68k_rotary_msb_cs,

    .input_p1_cs,
    .m68k_dsw_cs,

    // interrupt clear & watchdog
    .vbl_int_clr_cs,
    .cpu_int_clr_cs,
    .watchdog_clr_cs,

    .m68k_latch_cs, // write commands to z80 from 68k

    // z80

    .z80_rom_cs,
    .z80_ram_cs,
    .z80_banked_cs,

    .z80_latch_cs,
    .z80_latch_clr_cs,
    .z80_dac_cs,
    .z80_ym2413_cs,
    .z80_ym2203_cs,
    .z80_bank_set_cs

);

reg [7:0]  z80_latch;
reg [7:0]  m68k_latch;

// CPU outputs
wire m68k_rw         ;    // Read = 1, Write = 0
wire m68k_as_n       ;    // Address strobe
wire m68k_lds_n      ;    // Lower byte strobe
wire m68k_uds_n      ;    // Upper byte strobe
wire m68k_E;
wire [2:0] m68k_fc    ;   // Processor state
wire m68k_reset_n_o  ;    // Reset output signal
wire m68k_halted_n   ;    // Halt output

// CPU busses
wire [15:0] m68k_dout       ;
wire [23:0] m68k_a   /* synthesis keep */       ;
reg  [15:0] m68k_din        ;
//assign m68k_a[0] = 1'b0;

// CPU inputs
reg  m68k_dtack_n ;         // Data transfer ack (always ready)
reg  m68k_ipl0_n ;
reg  m68k_ipl1_n ;

// 68000 reset applied on its clock-enable edges only
wire m68k_reset_ce = ( reset | ss_reset68 ) & ce_20m;

// IPL as the 68000 samples it: a level set on this edge is seen on this edge
wire m68k_ipl0_cpu = m68k_ipl0_n & ~( vbl_sr == 2'b01 );
wire m68k_ipl1_cpu = m68k_ipl1_n & ~( hbl_sr == 2'b01 );

wire m68k_vpa_n = ~(m68k_a[22] & ~(m68k_uds_n & m68k_lds_n)) ;   //~int_ack
wire m68k_e ;

reg int_ack ;

wire reset_n;

reg fg_enable;
reg sp_enable;

// fx68k clock generation
reg fx68_phi1;

always @(posedge clk_sys) begin
    if ( clk_20M == 1 ) begin
        fx68_phi1 <= ~fx68_phi1;
    end
end

fx68k fx68k (
    // input
    .clk( clk_sys ),
    .HALTn(1'b1),
    .enPhi1( ce_20m &  fx68_phi1 ),
    .enPhi2( ce_20m & ~fx68_phi1 ),

    .extReset(m68k_reset_ce),
    .pwrUp(m68k_reset_ce),

    // output
    .eRWn(m68k_rw),
    .ASn(m68k_as_n),
    .LDSn(m68k_lds_n),
    .UDSn(m68k_uds_n),
    .E(m68k_e),
    .VMAn(),
    .FC0(m68k_fc[0]),
    .FC1(m68k_fc[1]),
    .FC2(m68k_fc[2]),
    .BGn(),
    .oRESETn(m68k_reset_n_o),
    .oHALTEDn(m68k_halted_n),

    // input
    .VPAn( m68k_vpa_n ),
    .DTACKn( m68k_dtack_n ),
    .BERRn(1'b1),
    .BRn(1'b1),
    .BGACKn(1'b1),

    .IPL0n(m68k_ipl0_cpu & ~ss_irq),
    .IPL1n(m68k_ipl1_cpu & ~ss_irq),
    .IPL2n(~ss_irq),

    // busses
    .iEdb(m68k_din),
    .oEdb(m68k_dout),
    .eab(m68k_a[23:1])
);


// z80 audio
wire    [7:0] z80_rom_data;
wire    [7:0] z80_rom_2_data;
wire    [7:0] z80_banked_data;
wire    [7:0] z80_ram_data;

wire   [15:0] z80_addr;
reg     [7:0] z80_din;
wire    [7:0] z80_dout;

wire z80_wr_n;
wire z80_rd_n;
//wire z80_wait_n = ~(z80_banked_cs & ~z80_banked_valid ) ;
reg z80_wait_n;
reg  z80_irq_n;
reg  z80_nmi_n;

wire IORQ_n;
wire MREQ_n;
wire M1_n;

T80pa z80 (
    .RESET_n    ( ~( reset | ss_resetz80 ) ),
    .CLK        ( clk_sys ),
    .CEN_p      ( clk_6M & ~holdz80 ),
    .CEN_n      ( ~clk_6M & ~holdz80 ),
    .WAIT_n     ( z80_wait_n ), // z80_wait_n
    .INT_n      ( 1'b1 ),
    .NMI_n      ( z80_nmi_n ),
    .BUSRQ_n    ( 1'b1 ),
    .RD_n       ( z80_rd_n ),
    .WR_n       ( z80_wr_n ),
    .A          ( z80_addr ),
    .DI         ( z80_din  ),
    .DO         ( z80_dout ),
    // unused
    .DIRSET     ( ss_dirset ),
    .DIR        ( ss_dir    ),
    .OUT0       ( 1'b0     ),
    .RFSH_n     (),
    .IORQ_n     ( IORQ_n ),
    .M1_n       ( M1_n ), // for interrupt ack
    .BUSAK_n    (),
    .HALT_n     ( 1'b1 ),
    .MREQ_n     ( MREQ_n ),
    .REG        ( z80_reg )
);

reg opl_wait ;
reg z80_nmi_suppress;

reg     io_port_a_wr ;

reg        opn_wr;
reg        opn_addr ;
reg  [7:0] opn_data ;

reg        opll_wr;
reg        opll_addr ;
reg  [7:0] opll_data ;

// sound ic write enable

reg signed [15:0] opll_sample;
reg signed [15:0] opn_sample;

assign AUDIO_S = 1'b1 ;

wire opll_sample_clk;
wire opn_sample_clk;

// OPLL (3.578 MHZ)
jt2413 ym2413 (
    .rst(reset),
    .clk(clk_sys),
    .cen(clk_4M & ~holdsnd),
    .din( ss_rp_opll ? ss_rp_din : z80_dout ),
    .addr( ss_rp_opll ? ss_rp_a0 : z80_addr[0] ),
    .cs_n( ss_rp_opll ? ~ss_rp_wr : ~z80_ym2413_cs ),
    .wr_n(0), //~opll_wr

    .snd(opll_sample),
    .sample(opll_sample_clk)
);

reg ym2203we ;
reg [7:0] ym2203_din;
reg ym2203addr;

always @ (posedge clk_sys) begin
    if ( ss_rp_opn ) begin
        ym2203we   <= ~ss_rp_wr ;
        ym2203_din <= ss_rp_din ;
        ym2203addr <= ss_rp_a0 ;
    end else begin
        ym2203we   <= ~z80_ym2203_cs ;
        ym2203_din <= z80_dout ;
        ym2203addr <= z80_addr[0] ;
    end
end

// OPN (3 MHZ)
jt03 ym2203 (
    .rst(reset),
    .clk(clk_sys), // clock in is signal 1H (6MHz/2)
    .cen(clk_3M & ~holdsnd),
    .din( ym2203_din ),
    .addr( ym2203addr ),
    .cs_n( ym2203we ),
    .wr_n( ym2203we ),

    .snd(opn_sample)
);

reg  signed  [7:0] dac ;
wire signed [15:0] dac_sample = { ~dac[7], dac[6:0], 8'h0 } ;

always @ * begin
    // mix audio
    AUDIO_L <= ss_mute ? 16'sd0 : ( ( opn_sample + opll_sample + dac_sample  ) * 5 ) >>> 4;  // ( 3*5 ) / 16th
    AUDIO_R <= ss_mute ? 16'sd0 : ( ( opn_sample + opll_sample + dac_sample  ) * 5 ) >>> 4;  // ( 3*5 ) / 16th
end

reg [16:0] gfx1_addr;
reg [17:0] gfx2_addr;

reg [7:0] gfx1_dout;
reg [7:0] gfx2_dout;

wire [15:0] m68k_ram_dout;
wire [15:0] m68k_sprite_dout;
wire [15:0] m68k_pal_dout;

// ioctl download addressing

wire fg_ioctl_wr    = rom_download & ioctl_wr & (ioctl_addr >= 24'h100000) & (ioctl_addr < 24'h110000) ;
wire z80_ioctl_wr   = rom_download & ioctl_wr & (ioctl_addr >= 24'h080000) & (ioctl_addr < 24'h088000) ;
wire z80_ioctl_2_wr = rom_download & ioctl_wr & (ioctl_addr >= 24'h088000) & (ioctl_addr < 24'h090000) ;

// RAM ports for save states and the hiscore restore (CPUs held)
wire        aux_en    = ss_aux_en | hs_aux_en;
wire  [2:0] aux_sel   = ss_aux_en ? ss_aux_sel   : hs_aux_sel;
wire [13:0] aux_addr  = ss_aux_en ? ss_aux_addr  : hs_aux_addr;
wire [15:0] aux_wdata = ss_aux_en ? ss_aux_wdata : hs_aux_wdata;
wire  [1:0] aux_we    = ss_aux_en ? ss_aux_we    : hs_aux_we;
wire [15:0] aux_rdata = ( aux_sel == 3'd0 ) ? m68k_ram_dout :
                        ( aux_sel == 3'd1 ) ? m68k_sprite_dout :
                        ( aux_sel == 3'd2 ) ? { 8'd0, m68k_fg_ram_dout[7:0] } :
                        ( aux_sel == 3'd3 ) ? m68k_pal_dout : { 8'd0, z80_ram_data };
wire [14:1] ram_a     = aux_en ? aux_addr : m68k_a[14:1];
wire        aux_z80   = aux_en && ( aux_sel == 3'd4 );
wire [15:0] ram_d     = aux_en ? aux_wdata : m68k_dout;

// main 68k ram high
dual_port_ram #(.LEN(8192)) ram8kx8_H (
    .clock_a ( clk_sys ),
    .address_a ( ram_a[13:1] ),
    .wren_a ( aux_en ? ( aux_sel == 3'd0 && aux_we[1] ) : ( !m68k_rw & m68k_ram_cs & !m68k_uds_n ) & ce_20m ),
    .data_a ( ram_d[15:8]  ),
    .q_a (  m68k_ram_dout[15:8] ),

    .clock_b ( clk_sys ),
    .address_b ( mcu_addr ),
    .wren_b ( mcu_wh ),
    .data_b ( mcu_din ),
    .q_b( mcu_dout )

    );

// main 68k ram low
dual_port_ram #(.LEN(8192)) ram8kx8_L (
    .clock_a ( clk_sys ),
    .address_a ( ram_a[13:1] ),
    .wren_a ( aux_en ? ( aux_sel == 3'd0 && aux_we[0] ) : ( !m68k_rw & m68k_ram_cs & !m68k_lds_n ) & ce_20m ),
    .data_a ( ram_d[7:0]  ),
    .q_a ( m68k_ram_dout[7:0] ),

    .clock_b ( clk_sys ),
    .address_b ( mcu_addr ),
    .wren_b ( mcu_wl ),
    .data_b ( mcu_din ),
    .q_b( mcu_dout )
    );

reg  [13:0] sprite_ram_addr;
wire [15:0] sprite_ram_dout /* synthesis keep */;

// main 68k sprite ram high
// 2kx16
dual_port_ram #(.LEN(16384)) sprite_ram_H (
    .clock_a ( clk_sys ),
    .address_a ( ram_a[14:1] ),
    .wren_a ( aux_en ? ( aux_sel == 3'd1 && aux_we[1] ) : ( !m68k_rw & m68k_spr_cs & !m68k_uds_n ) & ce_20m ),
    .data_a ( ram_d[15:8]  ),
    .q_a (  m68k_sprite_dout[15:8] ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_ram_addr ),
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( sprite_ram_dout[15:8] )
    );

// main 68k sprite ram low
dual_port_ram #(.LEN(16384)) sprite_ram_L (
    .clock_a ( clk_sys ),
    .address_a ( ram_a[14:1] ),
    .wren_a ( aux_en ? ( aux_sel == 3'd1 && aux_we[0] ) : ( !m68k_rw & m68k_spr_cs & !m68k_lds_n ) & ce_20m ),
    .data_a ( ram_d[7:0]  ),
    .q_a ( m68k_sprite_dout[7:0] ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_ram_addr ),
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( sprite_ram_dout[7:0] )
    );


wire [10:0] fg_ram_addr /* synthesis keep */;
wire [15:0] fg_ram_dout /* synthesis keep */;

wire [15:0] m68k_fg_ram_dout;

wire fg_u_w = !m68k_rw & m68k_fg_ram_cs & !m68k_uds_n ;
wire fg_l_w = !m68k_rw & m68k_fg_ram_cs & !m68k_lds_n ;

//// foreground high
//dual_port_ram #(.LEN(2048)) ram_fg_h (
//    .clock_a ( clk_20M ),
//    .address_a ( m68k_a[11:1] ),
//    .wren_a ( fg_u_w ),
//    .data_a ( m68k_dout[15:8]  ),
//    .q_a ( m68k_fg_ram_dout[15:8] ),
//
//    .clock_b ( clk_sys ),
//    .address_b ( fg_ram_addr ),
//    .wren_b ( 1'b0 ),
//    .data_b ( ),
//    .q_b( fg_ram_dout[15:8] )
//
//    );

// foreground low
dual_port_ram #(.LEN(2048)) ram_fg_l (
    .clock_a ( clk_sys ),
    .address_a ( ram_a[11:1] ),
    .wren_a ( aux_en ? ( aux_sel == 3'd2 && aux_we[0] ) : ( fg_l_w | fg_u_w ) & ce_20m ),
    .data_a ( ram_d[7:0] ),
    .q_a ( m68k_fg_ram_dout[7:0] ),

    .clock_b ( clk_sys ),
    .address_b ( fg_ram_addr ),
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( fg_ram_dout[7:0] )
    );


reg tile_pal_wr;
reg  [11:0] tile_pal_addr;
wire [15:0] tile_pal_dout;


// tile palette high
dual_port_ram #(.LEN(4096)) tile_pal_h (
    .clock_a ( clk_sys ),
    .address_a ( ram_a[12:1] ),
    .wren_a ( aux_en ? ( aux_sel == 3'd3 && aux_we[1] ) : ( !m68k_rw & m68k_pal_cs & !m68k_uds_n ) & ce_20m ),
    .data_a ( ram_d[15:8]  ),
    .q_a ( m68k_pal_dout[15:8]  ),

    .clock_b ( clk_sys ),
    .address_b ( tile_pal_addr ),
    .wren_b ( tile_pal_wr ),
    .data_b ( 8'd0 ),
    .q_b( tile_pal_dout[15:8] )
    );

//  tile palette low
dual_port_ram #(.LEN(4096)) tile_pal_l (
    .clock_a ( clk_sys ),
    .address_a ( ram_a[12:1] ),
    .wren_a ( aux_en ? ( aux_sel == 3'd3 && aux_we[0] ) : ( !m68k_rw & m68k_pal_cs & !m68k_lds_n ) & ce_20m ),
    .data_a ( ram_d[7:0]  ),
    .q_a ( m68k_pal_dout[7:0] ),

    .clock_b ( clk_sys ),
    .address_b ( tile_pal_addr ),
    .wren_b ( tile_pal_wr ),
    .data_b ( 8'd0 ),
    .q_b( tile_pal_dout[7:0] )
    );

//z80 program rom
reg   [4:0] z80_bank;
wire [18:0] z80_rom_addr = { z80_bank[4:0], z80_addr[13:0] }; // ( z80_rom_cs == 1 )    ? { 4'b0, z80_addr[14], z80_addr[13:0] } :
//                            ( z80_banked_cs == 1 ) ? {      z80_bank[4:0], z80_addr[13:0] } :
//                            0;

//always @ * begin
//    case (1)
//        z80_rom_cs:     z80_rom_addr = { 3'b0, z80_addr[14], z80_addr[13:0] };
//        z80_banked_cs:  z80_rom_addr = { z80_bank[4:0], z80_addr[13:0] };
//    endcase
//end

// sky adventure
dual_port_ram #(.LEN(32768)) z80_rom (
    .clock_a ( clk_sys ),
    .address_a ( z80_addr[14:0] ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( z80_rom_data[7:0] ),

    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[14:0] ),
    .wren_b ( z80_ioctl_wr ),
    .data_b ( ioctl_dout  ),
    .q_b( )
    );

dual_port_ram #(.LEN(32768)) z80_rom_bank2 (
    .clock_a ( clk_sys ),
    .address_a ( z80_addr[14:0] ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( z80_rom_2_data[7:0] ),

    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[14:0] ),
    .wren_b ( z80_ioctl_2_wr ),
    .data_b ( ioctl_dout  ),
    .q_b( )
    );

// z80 ram
dual_port_ram #(.LEN(2048)) z80_ram (
    .clock_b ( clk_sys ),
    .address_b ( aux_z80 ? aux_addr[10:0] : z80_addr[10:0] ),
    .wren_b ( aux_z80 ? aux_we[0] : ( z80_ram_cs & ~z80_wr_n ) & ce_6m & ~holdz80 ),
    .data_b ( aux_z80 ? aux_wdata[7:0] : z80_dout ),
    .q_b ( z80_ram_data )
    );

//reg [16:0] upd_addr ;
//wire [7:0] upd_dout ;

//adpcm sample rom
//dual_port_ram #(.LEN(131072)) upd_rom (
//    .clock_a ( clk_sys ),
//    .address_a ( upd_addr[16:0] ),
//    .wren_a ( 1'b0 ),
//    .data_a ( ),
//    .q_a ( upd_dout[7:0] ),
//
//    .clock_b ( clk_sys ),
//    .address_b ( ioctl_addr[16:0] ),
//    .wren_b ( upd_ioctl_wr ),
//    .data_b ( ioctl_dout  ),
//    .q_b( )
//    );

wire [15:0] spr_pal_dout ;
wire [15:0] m68k_spr_pal_dout ;

reg  [8:0]  sprite_buffer_addr;  // 128 sprites
reg  [63:0] sprite_buffer_din;
wire [63:0] sprite_buffer_dout;
reg  sprite_buffer_w;

dual_port_ram #(.LEN(512), .DATA_WIDTH(64)) sprite_buffer (
    .clock_a ( clk_sys ),
    .address_a ( sprite_buffer_addr ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( sprite_buffer_dout ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_buffer_addr ),
    .wren_b ( sprite_buffer_w ),
    .data_b ( sprite_buffer_din  ),
    .q_b( )

    );

reg          line_buf_fg_w;
reg   [9:0]  line_buf_addr_w;
reg   [9:0]  line_buf_addr_r ;

reg  [15:0]  line_buf_fg_din;
wire [15:0]  line_buf_fg_out;

reg   [9:0]  spr_buf_addr_w;
reg          spr_buf_w;
reg  [15:0]  spr_buf_din;
wire [15:0]  spr_buf_dout;

dual_port_ram #(.LEN(1024), .DATA_WIDTH(16)) spr_buffer_ram (
    .clock_a ( clk_sys ),
    .address_a ( spr_buf_addr_w ),
    .wren_a ( spr_buf_w ),
    .data_a ( spr_buf_din ),
    .q_a (  ),

    .clock_b ( clk_sys ),
    .address_b ( line_buf_addr_r ),
    .wren_b ( 0 ),
    .q_b ( spr_buf_dout )
    );

// two line buffer
dual_port_ram #(.LEN(1024), .DATA_WIDTH(16)) line_buffer_ram_fg (
    .clock_a ( clk_sys ),
    .address_a ( line_buf_addr_w ),
    .wren_a ( line_buf_fg_w ),
    .data_a ( line_buf_fg_din ),
    .q_a ( ),

    .clock_b ( clk_sys ),
    .address_b ( line_buf_addr_r ),
    .wren_b ( 0 ),
    .q_b ( line_buf_fg_out )
    );


wire z80_banked_valid;

wire [15:0] m68k_rom_data;
wire        m68k_rom_valid;

wire [15:0] m68k_rom_2_data;
wire        m68k_rom_2_valid;

reg         sprite_rom_cs;
reg  [19:0] sprite_rom_addr;
wire [31:0] sprite_rom_data;
wire        sprite_rom_valid;

reg         sprite_cache_cs;
reg  [19:0] sprite_cache_addr;
wire [31:0] sprite_cache_data;
wire        sprite_cache_valid;

//reg  [16:0] upd_rom_addr;
//wire  [7:0] upd_rom_data;
//wire        upd_rom_cs;
//wire        upd_rom_valid;

reg [15:0] fg_rom_addr;
reg  [7:0] fg_rom_data;

//10000,11000,00000,01000, 10001,11001,00001,01001
//00000,00001,00010,00011, 00100,00101,00110,00111

// ( a[15:5], a[2:0], ~a[4], a[3] )

// ( t[15:5], ~t[1], t[0], t[4:2] )

// swizzle the tile bitmap loading so each 4 pixels is one 16 bit read
//wire [15:0] fg_ioctl_addr = { ioctl_addr[15:5], ioctl_addr[2:0], ~ioctl_addr[4], ioctl_addr[3] } ;

dual_port_ram #(.LEN(65536)) fg_rom (
    .clock_a ( clk_sys ),
    .address_a ( fg_rom_addr ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( fg_rom_data ),

    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[15:0] ),
    .wren_b ( fg_ioctl_wr ),
    .data_b ( ioctl_dout  ),
    .q_b( )
    );

wire        prog_cache_rom_cs;
wire [15:0] prog_cache_data;
wire        prog_cache_valid;
wire [23:1] prog_cache_addr;

wire        sound_cache_rom_cs;
wire [7:0]  sound_cache_data;
wire        sound_cache_valid;
wire [23:1] sound_cache_addr;

reg  [39:0] global_count;
reg  [23:0] rom_count;
reg  [23:0] rom_2_count;
reg  [23:0] sprite_count;
reg  [23:0] sound_count;

reg  rom_count_en;
reg  rom_2_count_en;
reg  sprite_count_en;
reg  sound_count_en;

always @ (posedge clk_sys) begin
    if ( reset ) begin
        global_count <= 0;
        rom_count <= 0;
        rom_2_count <= 0;
        sprite_count <= 0;
        sound_count <= 0;

        rom_count_en <= 0;
        rom_2_count_en <= 0;
        sprite_count_en <= 0;
        sound_count_en <= 0;
    end else begin
        if ( vbl == 1 ) begin
            global_count <= 0;
            rom_count <= 0;
            rom_2_count <= 0;
            sprite_count <= 0;
            sound_count <= 0;
        end else begin
            global_count <= global_count + 1;

            rom_count_en <= ( rom_count_en | prog_cache_rom_cs ) & ~prog_cache_valid;
            if ( rom_count_en == 1 ) begin
                rom_count <= rom_count + 1;
            end

            rom_2_count_en <= ( rom_2_count_en | m68k_rom_2_cs ) & ~m68k_rom_2_valid;
            if ( rom_2_count_en == 1 ) begin
                rom_2_count <= rom_2_count + 1;
            end

            sprite_count_en <= ( sprite_count_en | sprite_cache_cs ) & ~sprite_cache_valid;
            if ( sprite_count_en == 1 ) begin
                sprite_count <= sprite_count + 1;
            end

            sound_count_en <= ( sound_count_en | z80_banked_cs ) & ~z80_banked_valid;
            if ( sound_count_en == 1 ) begin
                sound_count <= sound_count + 1;
            end
        end
    end
end

rom_controller rom_controller
(
    .reset(reset),

    // clock
    .clk(clk_sys),

    // program ROM interface
    .prog_rom_cs(m68k_rom_cs),
    .prog_rom_oe(1),
    .prog_rom_addr(m68k_a[23:1]),
    .prog_rom_data(m68k_rom_data),
    .prog_rom_data_valid(m68k_rom_valid),

//    .prog_rom_cs(prog_cache_rom_cs),
//    .prog_rom_oe(1),
//    .prog_rom_addr(prog_cache_addr),
//    .prog_rom_data(prog_cache_data),
//    .prog_rom_data_valid(prog_cache_valid),

    .prog_rom_2_cs(m68k_rom_2_cs),
    .prog_rom_2_oe(1),
    .prog_rom_2_addr(m68k_a[23:1]),
    .prog_rom_2_data(m68k_rom_2_data),
    .prog_rom_2_data_valid(m68k_rom_2_valid),

    // sprite ROM interface
    .sprite_rom_cs(sprite_rom_cs),
    .sprite_rom_oe(1),
    .sprite_rom_addr(sprite_rom_addr),
    .sprite_rom_data(sprite_rom_data),
    .sprite_rom_data_valid(sprite_rom_valid),

//    .sprite_rom_cs(sprite_cache_cs),
//    .sprite_rom_oe(1),
//    .sprite_rom_addr(sprite_cache_addr),
//    .sprite_rom_data(sprite_cache_data),
//    .sprite_rom_data_valid(sprite_cache_valid),

    // sound ROM interface
//    .sound_rom_cs(z80_banked_cs),
//    .sound_rom_oe(1),
//    .sound_rom_addr(z80_rom_addr),
//    .sound_rom_data(z80_banked_data),
//    .sound_rom_data_valid(z80_banked_valid),

    // to rom controller
    .sound_rom_cs(sound_cache_rom_cs),
    .sound_rom_oe(1),
    .sound_rom_addr(sound_cache_addr),
    .sound_rom_data(sound_cache_data),
    .sound_rom_data_valid(sound_cache_valid),

    // IOCTL interface
    .ioctl_addr(ioctl_addr),
    .ioctl_data(ioctl_dout),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr & rom_download),
    .ioctl_download(rom_download),

    // SDRAM interface
    .sdram_addr(sdram_addr),
    .sdram_data(sdram_data),
    .sdram_we(sdram_we),
    .sdram_req(sdram_req),
    .sdram_ack(sdram_ack),
    .sdram_valid(sdram_valid),
    .sdram_q(sdram_q)
  );

//cache prog_cache
//(
//    .reset(reset),
//    .clk(clk_sys),
//
//    // client
//    .cache_req(m68k_rom_cs),
//    .cache_addr(m68k_a[17:1]),
//    .cache_valid(m68k_rom_valid),
//    .cache_data(m68k_rom_data),
//
//    // to rom controller
//    .rom_req(prog_cache_rom_cs),
//    .rom_addr(prog_cache_addr),
//    .rom_valid(prog_cache_valid),
//    .rom_data(prog_cache_data)
//);

//tile_cache tile_cache
//(
//    .clk(clk_sys),
//    .reset(reset),
//
//    // client
//    .cache_req(sprite_rom_cs),
//    .cache_addr(sprite_rom_addr),
//    .cache_data(sprite_rom_data),
//    .cache_valid(sprite_rom_valid),
//
//    // to rom controller
//    .rom_req(sprite_cache_cs),
//    .rom_addr(sprite_cache_addr),
//    .rom_data(sprite_cache_data),
//    .rom_valid(sprite_cache_valid)
//
//);

sound_cache sound_cache
(
    .clk(clk_sys),
    .reset(reset),

    // client
    .cache_req(z80_banked_cs),
    .cache_addr(z80_rom_addr),
    .cache_data(z80_banked_data),
    .cache_valid(z80_banked_valid),

    // to rom controller
    .rom_req(sound_cache_rom_cs),
    .rom_addr(sound_cache_addr),
    .rom_data(sound_cache_data),
    .rom_valid(sound_cache_valid)

);


reg  [22:0] sdram_addr;
reg  [31:0] sdram_data;
reg         sdram_we;
reg         sdram_req;

wire        sdram_ack;
wire        sdram_valid;
wire [31:0] sdram_q;

sdram #(.CLK_FREQ( (CLKSYS+0.0))) sdram
(
  .reset(~pll_locked),
  .clk(clk_sys),

  // controller interface
  .addr(sdram_addr),
  .data(sdram_data),
  .we(sdram_we),
  .req(sdram_req),

  .ack(sdram_ack),
  .valid(sdram_valid),
  .q(sdram_q),

  // SDRAM interface
  .sdram_a(SDRAM_A),
  .sdram_ba(SDRAM_BA),
  .sdram_dq(SDRAM_DQ),
  .sdram_cke(SDRAM_CKE),
  .sdram_cs_n(SDRAM_nCS),
  .sdram_ras_n(SDRAM_nRAS),
  .sdram_cas_n(SDRAM_nCAS),
  .sdram_we_n(SDRAM_nWE),
  .sdram_dqml(SDRAM_DQML),
  .sdram_dqmh(SDRAM_DQMH)
);

//////////////////////////////////////////////////////////////////
// save states


alpha68k_ss alpha68k_ss (
    .clk(clk_sys),
    .reset(reset),
    .do_save(ss_save),
    .do_restore(ss_load),
    .index(ss_slot),
    .ddr(ddr_ss),

    .cpu_as_n(m68k_as_n),
    .cpu_rw(m68k_rw),
    .cpu_uds_n(m68k_uds_n),
    .cpu_lds_n(m68k_lds_n),
    .cpu_fc(m68k_fc),
    .cpu_a(m68k_a[23:1]),
    .cpu_dout(m68k_dout),
    .ce_cpu(ce_20m),
    .ovr_rd(ss_ovr_rd),
    .ovr_data(ss_ovr_data),
    .hold68(ss_hold68),
    .cpu_execute(ss_cpu_execute),
    .irq7(ss_irq),
    .reset68(ss_reset68),
    .active(ss_active),

    .z80_m1_n(M1_n),
    .z80_reg(z80_reg),
    .holdz80(ss_holdz80),
    .z80_run(ss_z80_run),
    .resetz80(ss_resetz80),
    .dirset(ss_dirset),
    .dir(ss_dir),

    .holdsnd(ss_holdsnd),
    .mute(ss_mute),
    .opn_wr(~ym2203we),
    .opn_a0(ym2203addr),
    .opn_din(ym2203_din),
    .opll_wr(ss_rp_opll ? ss_rp_wr : z80_ym2413_cs),
    .opll_a0(ss_rp_opll ? ss_rp_a0 : z80_addr[0]),
    .opll_din(ss_rp_opll ? ss_rp_din : z80_dout),
    .rp_opn(ss_rp_opn),
    .rp_opll(ss_rp_opll),
    .rp_wr(ss_rp_wr),
    .rp_a0(ss_rp_a0),
    .rp_din(ss_rp_din),

    .misc_in(ss_misc_in),
    .misc_out(ss_misc_out),
    .misc_wr(ss_misc_wr),

    .aux_en(ss_aux_en),
    .aux_sel(ss_aux_sel),
    .aux_addr(ss_aux_addr),
    .aux_wdata(ss_aux_wdata),
    .aux_we(ss_aux_we),
    .aux_rdata(aux_rdata)
);

// keyboard F1 / Alt only (F2-F4 are core keys)
reg [10:0] ss_ps2_key;
reg        ss_ps2_tog;
always @(posedge clk_sys) begin
    ss_ps2_tog <= ps2_key[10];
    if ( ss_ps2_tog != ps2_key[10] && ( ps2_key[7:0] == 8'h05 || ps2_key[7:0] == 8'h11 ) ) ss_ps2_key <= ps2_key;
end

savestate_ui #(.INFO_TIMEOUT_BITS(25)) savestate_ui
(
    .clk            (clk_sys),
    .ps2_key        (ss_ps2_key),
    .allow_ss       (~hs_hold68),
    .joySS          (joy0[9]),
    .joyRight       (joy0[0]),
    .joyLeft        (joy0[1]),
    .joyDown        (joy0[2]),
    .joyUp          (joy0[3]),
    .joyStart       (1'b0),
    .joyRewind      (1'b0),
    .rewindEnable   (1'b0),
    .status_slot    (status[66:65]),
    .autoincslot    (status[64]),
    .OSD_saveload   (status[68:67]),
    .ss_save        (ss_save),
    .ss_load        (ss_load),
    .ss_info_req    (ss_info_req),
    .ss_info        (ss_info),
    .statusUpdate   (ss_status_set),
    .selected_slot  (ss_slot)
);

//////////////////////////////////////////////////////////////////
// hiscores


// 68000 held long enough for the RAM ports to be free
reg   [3:0] hold_cnt;
always @(posedge clk_sys) hold_cnt <= ( hold68 && !clk_20M ) ? ( &hold_cnt ? hold_cnt : hold_cnt + 1'd1 ) : 4'd0;

hiscore hiscore (
    .clk(clk_sys),
    .reset(reset),
    .vblank(vbl),
    .osd_open(OSD_STATUS),
    .autosave(~status[69]),
    .save_req(status[70]),

    .ioctl_download(ioctl_download),
    .ioctl_upload(ioctl_upload),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_index(ioctl_index),
    .ioctl_din(ioctl_din),
    .upload_req(hs_upload_req),
    .present(hs_present),

    .cpu_wr(ce_20m & !m68k_rw & !m68k_as_n & ( !m68k_uds_n | !m68k_lds_n )),
    .cpu_a(m68k_a[23:1]),
    .cpu_uds_n(m68k_uds_n),
    .cpu_lds_n(m68k_lds_n),
    .cpu_dout(m68k_dout),

    .hold68(hs_hold68),
    .held(&hold_cnt),
    .aux_en(hs_aux_en),
    .aux_sel(hs_aux_sel),
    .aux_addr(hs_aux_addr),
    .aux_wdata(hs_aux_wdata),
    .aux_we(hs_aux_we),
    .busy_other(ss_active)
);

endmodule

module delay
(
    input clk,
    input clk_en,
    input i,
    output o
);

reg [5:0] r;

assign o = r[0];

always @(posedge clk) begin
    if ( clk_en == 1 ) begin
        r <= { r[4:0], i };
    end
end

endmodule

//// N > M, N > 1
//module clock_divider
//#(parameter N=2, parameter M=1)
//(
//    input reset,
//    input clk_in,
//    output clk_out
//);
//
//reg [15:0] count;
//
//always @ (posedge clk_in) begin
//    if ( reset == 1 ) begin
//        clk_out <= 0;
//        count <= 0;
//    end else begin
//        clk_out <= 0;
//        if ( count > (N-1) ) begin // N ( divider - 1 )
//            clk_20M <= 1 ;
//            count <= count - (N-M-1);
//        end else begin
//            count <= count + M; // M ( muliplier )
//        end
//    end
//end

// endmodule
