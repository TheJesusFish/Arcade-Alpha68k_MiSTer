//============================================================================
//
//  Save states for the Alpha Denshi 68000 core.
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//============================================================================

module alpha68k_ss
(
    input             clk,
    input             reset,

    input             do_save,
    input             do_restore,
    input       [1:0] index,
    ddr_if.to_host    ddr,

    // 68000
    input             cpu_as_n,
    input             cpu_rw,
    input             cpu_uds_n,
    input             cpu_lds_n,
    input       [2:0] cpu_fc,
    input      [23:1] cpu_a,
    input      [15:0] cpu_dout,
    input             ce_cpu,
    output            ovr_rd,
    output reg [15:0] ovr_data,
    output reg        hold68,
    output reg        cpu_execute,
    output reg        irq7,
    output reg        reset68,
    output            active,

    // Z80
    input             z80_m1_n,
    input     [211:0] z80_reg,
    output reg        holdz80,
    output            z80_run,
    output reg        resetz80,
    output reg        dirset,
    output    [211:0] dir,

    // sound chips
    output reg        holdsnd,
    output reg        mute,
    input             opn_wr,
    input             opn_a0,
    input       [7:0] opn_din,
    input             opll_wr,
    input             opll_a0,
    input       [7:0] opll_din,
    output reg        rp_opn,
    output reg        rp_opll,
    output reg        rp_wr,
    output reg        rp_a0,
    output reg  [7:0] rp_din,

    // core registers
    input     [143:0] misc_in,
    output    [143:0] misc_out,
    output            misc_wr,

    // RAM ports while frozen
    output reg        aux_en,
    output reg  [2:0] aux_sel,
    output reg [13:0] aux_addr,
    output reg [15:0] aux_wdata,
    output reg  [1:0] aux_we,
    input      [15:0] aux_rdata
);

localparam [7:0] SSIDX_GLOBAL = 0, SSIDX_WORK_RAM = 1, SSIDX_SPR_RAM = 2, SSIDX_FG_RAM = 3, SSIDX_PAL_RAM = 4,
                 SSIDX_Z80_RAM = 5, SSIDX_Z80 = 6, SSIDX_MISC = 7, SSIDX_SND = 8, SSIDX_SND_SEL = 9;

// level-7 handler at $3F0000: push all registers, store SSP at $3F0000, pop, rte (restart at $3F0008)
wire [15:0] handler[16] = '{
    16'h48e7, 16'hfffe,             // movem.l d0-d7/a0-a6,-(a7)
    16'h4e6e,                       // move.l usp,a6
    16'h2f0e,                       // move.l a6,-(a7)
    16'h4df9, 16'h003f, 16'h0000,   // lea $3f0000,a6
    16'h2c8f,                       // move.l a7,(a6)
    16'h2c5f,                       // move.l (a7)+,a6
    16'h4e66,                       // move.l a6,usp
    16'h4cdf, 16'h7fff,             // movem.l (a7)+,d0-d7/a0-a6
    16'h4e73,                       // rte
    16'h0000, 16'h0000, 16'h0000
};

typedef enum bit [4:0] {
    SST_IDLE,
    SST_SAVE_STOP68,
    SST_SAVE_STOPZ80,
    SST_SAVE_IRQ,
    SST_SAVE_SSP,
    SST_SAVE_SETTLE,
    SST_SAVE_WRITE,
    SST_SAVE_RELEASE,
    SST_SAVE_EXIT,
    SST_RST_STOP,
    SST_RST_READ,
    SST_RST_REPLAY,
    SST_RST_Z80,
    SST_RST_68K_RESET,
    SST_RST_RELEASE,
    SST_RST_68K_RUN
} ss_state_t;

ss_state_t state = SST_IDLE;
assign active = ( state != SST_IDLE );
// a save lets the Z80 reach its next opcode fetch even while the core is paused
assign z80_run = ( state == SST_SAVE_STOPZ80 );

reg  [31:0] saved_ssp;
reg  [31:0] restore_ssp;
reg  [15:0] cnt;
reg         m1_l;
reg         ss_write, ss_read;
wire        ss_busy;

wire handler_hit = ( cpu_a[23:5] == 19'h1f800 );                 // $3F0000-$3F001F
wire vec_hit     = ( cpu_a[23:2] == 22'h00001f );                // $00007C-$00007F (level-7 autovector)
wire rst_hit     = ( cpu_a[23:3] == 21'h0 );                     // $000000-$000007 (reset vectors)

wire ovr_save    = ( state == SST_SAVE_SSP ) || ( state == SST_SAVE_SETTLE ) || ( state == SST_SAVE_WRITE ) ||
                   ( state == SST_SAVE_RELEASE ) || ( state == SST_SAVE_EXIT );
wire ovr_rst     = ( state == SST_RST_68K_RESET ) || ( state == SST_RST_RELEASE ) || ( state == SST_RST_68K_RUN );

assign ovr_rd = cpu_rw & ( ( ( ovr_save | ovr_rst ) & handler_hit ) | ( ovr_save & vec_hit ) | ( ovr_rst & rst_hit ) );

always @(*) begin
    if ( handler_hit )
        ovr_data = handler[cpu_a[4:1]];
    else if ( vec_hit )
        ovr_data = cpu_a[1] ? 16'h0000 : 16'h003f;
    else case ( cpu_a[2:1] )
        2'd0: ovr_data = restore_ssp[31:16];
        2'd1: ovr_data = restore_ssp[15:0];
        2'd2: ovr_data = 16'h003f;
        2'd3: ovr_data = 16'h0008;
    endcase
end

// program fetch outside the override region ends the 68000 part of a sequence
wire prog_fetch_out = !cpu_as_n && cpu_rw && !cpu_uds_n && !cpu_lds_n && ( cpu_fc == 3'b110 ) && !handler_hit && !( ovr_rst & rst_hit );

////////////////////////////////////////////////////////////////////////////
// chunk bus

ssbus_if ssbus();
ssbus_if ssb[4]();

ssbus_mux #(.COUNT(4)) ssmux (
    .clk,
    .slave(ssbus),
    .masters(ssb)
);

save_state_data save_state_data (
    .clk,
    .reset,
    .ddr,
    .read_start(ss_read),
    .write_start(ss_write),
    .index,
    .busy(ss_busy),
    .ssbus(ssbus)
);

// global: saved SSP
always @(posedge clk) begin
    ssb[0].setup(SSIDX_GLOBAL, 1, 2);
    if ( ssb[0].access(SSIDX_GLOBAL) ) begin
        if ( ssb[0].read ) begin
            ssb[0].read_response(SSIDX_GLOBAL, { 32'd0, saved_ssp });
        end else if ( ssb[0].write ) begin
            restore_ssp <= ssb[0].data[31:0];
            ssb[0].write_ack(SSIDX_GLOBAL);
        end
    end
end

// Z80 registers (T80 REG / DIR), padded to whole 16-bit words
wire [223:0] z80_bits;
assign dir = z80_bits[211:0];

auto_save_adaptor #(.N_BITS(224), .SS_IDX(SSIDX_Z80)) z80_ss (
    .clk,
    .ssbus(ssb[1]),
    .bits_in({ 12'd0, z80_reg }),
    .bits_out(z80_bits),
    .bits_wr()
);

// core registers
auto_save_adaptor #(.N_BITS(144), .SS_IDX(SSIDX_MISC)) misc_ss (
    .clk,
    .ssbus(ssb[2]),
    .bits_in(misc_in),
    .bits_out(misc_out),
    .bits_wr(misc_wr)
);

////////////////////////////////////////////////////////////////////////////
// sound chip register shadows: [0..255] YM2203, [256..319] YM2413

reg   [7:0] snd_shadow[512];
reg   [7:0] opn_sel;
reg   [1:0] opn_div;
reg   [5:0] opll_sel;
reg   [8:0] snd_waddr;
reg   [7:0] snd_wdata;
reg         snd_we;
reg   [8:0] snd_raddr;
reg   [7:0] snd_q;
reg   [8:0] clr_addr;
reg         clr_busy;

always @(posedge clk) begin
    if ( snd_we ) snd_shadow[snd_waddr] <= snd_wdata;
    snd_q <= snd_shadow[snd_raddr];
end

// chunk bridge: RAMs through the aux ports, the sound shadow, selects
typedef enum bit [2:0] { BR_IDLE, BR_WR, BR_RD1, BR_RD2, BR_WAIT } br_state_t;
br_state_t br = BR_IDLE;

wire [7:0]  br_sel  = ssb[3].select;
reg         br_known;
reg   [1:0] br_width;
reg  [31:0] br_count;

always @(*) begin
    br_known = 1;
    br_width = 1;
    br_count = 0;
    case ( br_sel )
        SSIDX_WORK_RAM: begin br_width = 1; br_count = 8192;  end
        SSIDX_SPR_RAM:  begin br_width = 1; br_count = 16384; end
        SSIDX_FG_RAM:   begin br_width = 0; br_count = 2048;  end
        SSIDX_PAL_RAM:  begin br_width = 1; br_count = 4096;  end
        SSIDX_Z80_RAM:  begin br_width = 0; br_count = 2048;  end
        SSIDX_SND:      begin br_width = 0; br_count = 320;   end
        SSIDX_SND_SEL:  begin br_width = 1; br_count = 1;     end
        default:        br_known = 0;
    endcase
end

wire [2:0] br_aux = ( br_sel == SSIDX_WORK_RAM ) ? 3'd0 :
                    ( br_sel == SSIDX_SPR_RAM )  ? 3'd1 :
                    ( br_sel == SSIDX_FG_RAM )   ? 3'd2 :
                    ( br_sel == SSIDX_PAL_RAM )  ? 3'd3 : 3'd4;

reg        sel_wr;
reg [15:0] sel_wdata;

always @(posedge clk) begin
    ssb[3].ack <= 0;
    aux_we     <= 0;
    sel_wr     <= 0;

    case ( br )
        BR_IDLE: begin
            if ( ssb[3].query ) begin
                if ( br_known ) begin
                    ssb[3].data_out <= { br_sel, 22'd0, br_width, br_count };
                    ssb[3].ack      <= 1;
                end
                br <= BR_WAIT;
            end else if ( br_known && ( ssb[3].read || ssb[3].write ) ) begin
                aux_sel   <= br_aux;
                aux_addr  <= ssb[3].addr[13:0];
                aux_wdata <= ssb[3].data[15:0];
                snd_raddr <= ssb[3].addr[8:0];
                if ( ssb[3].write ) begin
                    if ( br_sel == SSIDX_SND_SEL ) begin
                        sel_wr    <= 1;
                        sel_wdata <= ssb[3].data[15:0];
                    end else if ( br_sel != SSIDX_SND ) begin
                        aux_we <= ( br_width == 1 ) ? 2'b11 : 2'b01;
                    end
                    br <= BR_WR;
                end else begin
                    br <= BR_RD1;
                end
            end
        end

        BR_WR: begin
            ssb[3].ack <= 1;
            br <= BR_WAIT;
        end

        BR_RD1: begin
            br <= BR_RD2;
        end

        BR_RD2: begin
            ssb[3].data_out <= ( br_sel == SSIDX_SND )     ? { 56'd0, snd_q } :
                               ( br_sel == SSIDX_SND_SEL ) ? { 48'd0, opn_sel, opn_div, opll_sel } :
                               ( br_width == 0 )           ? { 56'd0, aux_rdata[7:0] } : { 48'd0, aux_rdata };
            ssb[3].ack <= 1;
            br <= BR_WAIT;
        end

        BR_WAIT: begin
            if ( !ssb[3].read && !ssb[3].write && !ssb[3].query ) br <= BR_IDLE;
        end

        default: br <= BR_IDLE;
    endcase

    // replay reads the shadow
    if ( rp_go ) snd_raddr <= ( rp_step < 10'd256 ) ? { 1'b0, rp_reg } : { 3'b100, rp_step[5:0] };
end

////////////////////////////////////////////////////////////////////////////
// sound register replay

reg  [9:0] rp_step;          // register index across both chips
reg [12:0] rp_wait;
reg  [2:0] rp_phase;
reg        rp_go, rp_done;

// YM2203 replay order: prescaler, 0x00-0x9f, A-group with high latch first, 0xb0-0xff; key on (0x28) skipped
function [7:0] opn_order(input [7:0] i);
    case ( i )
        8'ha0: opn_order = 8'ha4; 8'ha1: opn_order = 8'ha0; 8'ha2: opn_order = 8'ha5; 8'ha3: opn_order = 8'ha1;
        8'ha4: opn_order = 8'ha6; 8'ha5: opn_order = 8'ha2; 8'ha6: opn_order = 8'ha3; 8'ha7: opn_order = 8'ha7;
        8'ha8: opn_order = 8'hac; 8'ha9: opn_order = 8'ha8; 8'haa: opn_order = 8'had; 8'hab: opn_order = 8'ha9;
        8'hac: opn_order = 8'hae; 8'had: opn_order = 8'haa; 8'hae: opn_order = 8'hab; 8'haf: opn_order = 8'haf;
        default: opn_order = i;
    endcase
endfunction

wire [7:0] rp_reg  = ( rp_step < 10'd256 ) ? opn_order(rp_step[7:0]) : { 2'b00, rp_step[5:0] };
wire       rp_skip = ( rp_step < 10'd256 ) && ( ( rp_reg == 8'h28 ) || ( rp_reg >= 8'h2d && rp_reg <= 8'h2f ) );

////////////////////////////////////////////////////////////////////////////
// shadow write port: clear on reset, snoop chip writes, restore from the chunk bus

always @(posedge clk) begin
    snd_we <= 0;
    if ( reset ) begin
        clr_busy  <= 1;
        clr_addr  <= 0;
        opn_sel   <= 0;
        opn_div   <= 2'b10;
        opll_sel  <= 0;
    end
    if ( clr_busy ) begin
        snd_we    <= 1;
        snd_waddr <= clr_addr;
        snd_wdata <= 0;
        clr_addr  <= clr_addr + 1'd1;
        if ( &clr_addr ) clr_busy <= 0;
    end else if ( br == BR_IDLE && ssb[3].write && !ssb[3].query && br_sel == SSIDX_SND ) begin
        snd_we    <= 1;
        snd_waddr <= ssb[3].addr[8:0];
        snd_wdata <= ssb[3].data[7:0];
    end else if ( opn_wr ) begin
        if ( !opn_a0 ) begin
            opn_sel <= opn_din;
            case ( opn_din )
                8'h2d: opn_div[1] <= 1'b1;
                8'h2e: opn_div[0] <= 1'b1;
                8'h2f: opn_div    <= 2'b00;
                default: ;
            endcase
        end else begin
            snd_we    <= 1;
            snd_waddr <= { 1'b0, opn_sel };
            snd_wdata <= opn_din;
        end
    end else if ( opll_wr ) begin
        if ( !opll_a0 ) begin
            opll_sel <= opll_din[5:0];
        end else begin
            snd_we    <= 1;
            snd_waddr <= { 3'b100, opll_sel };
            snd_wdata <= opll_din;
        end
    end
    if ( sel_wr ) begin
        opn_sel  <= sel_wdata[15:8];
        opn_div  <= sel_wdata[7:6];
        opll_sel <= sel_wdata[5:0];
    end
end

// replay sequencer: per register an address write and a data write, each held 8 clk, then 4096 clk for the chip to update
always @(posedge clk) begin
    if ( !rp_go ) begin
        rp_step  <= 0;
        rp_phase <= 0;
        rp_wait  <= 0;
        rp_done  <= 0;
        rp_opn   <= 0;
        rp_opll  <= 0;
        rp_wr    <= 0;
    end else if ( !rp_done ) begin
        rp_opn  <= ( rp_step < 10'd256 ) || ( rp_step >= 10'd320 );
        rp_opll <= ( rp_step >= 10'd256 ) && ( rp_step < 10'd320 );
        rp_wait <= rp_wait + 1'd1;
        case ( rp_phase )
            // prescaler: 0x2f, then 0x2d / 0x2e as saved (address-only writes)
            0: begin
                rp_step <= 10'd320;
                rp_a0 <= 0; rp_din <= 8'h2f; rp_wr <= ( rp_wait < 8 );
                if ( rp_wait == 13'd31 ) begin rp_wait <= 0; rp_phase <= 1; end
            end
            1: begin
                rp_a0 <= 0; rp_din <= 8'h2d; rp_wr <= opn_div[1] && ( rp_wait < 8 );
                if ( rp_wait == 13'd31 ) begin rp_wait <= 0; rp_phase <= 2; end
            end
            2: begin
                rp_a0 <= 0; rp_din <= 8'h2e; rp_wr <= opn_div[0] && ( rp_wait < 8 );
                if ( rp_wait == 13'd31 ) begin rp_wait <= 0; rp_phase <= 3; rp_step <= 0; end
            end
            // registers
            3: begin
                if ( rp_skip ) begin
                    rp_wait <= 0;
                    rp_step <= rp_step + 1'd1;
                end else begin
                    if ( rp_wait < 8 ) begin
                        rp_a0 <= 0; rp_din <= rp_reg; rp_wr <= 1;
                    end else if ( rp_wait < 16 ) begin
                        rp_wr <= 0;
                    end else if ( rp_wait < 24 ) begin
                        rp_a0 <= 1; rp_din <= snd_q; rp_wr <= 1;
                    end else begin
                        rp_wr <= 0;
                    end
                    if ( rp_wait == 13'd4120 ) begin
                        rp_wait <= 0;
                        if ( rp_step == 10'd319 ) rp_phase <= 4;
                        else rp_step <= rp_step + 1'd1;
                    end
                end
            end
            // restore the selects the game left in the chips
            4: begin
                rp_opn <= 1; rp_opll <= 0;
                rp_a0 <= 0; rp_din <= opn_sel; rp_wr <= ( rp_wait < 8 );
                if ( rp_wait == 13'd31 ) begin rp_wait <= 0; rp_phase <= 5; end
            end
            5: begin
                rp_opn <= 0; rp_opll <= 1;
                rp_a0 <= 0; rp_din <= { 2'b00, opll_sel }; rp_wr <= ( rp_wait < 8 );
                if ( rp_wait == 13'd31 ) begin rp_wait <= 0; rp_done <= 1; rp_opn <= 0; rp_opll <= 0; rp_wr <= 0; end
            end
            default: rp_done <= 1;
        endcase
    end else begin
        rp_opn  <= 0;
        rp_opll <= 0;
        rp_wr   <= 0;
    end
end

////////////////////////////////////////////////////////////////////////////
// sequence

always @(posedge clk) begin
    ss_write <= 0;
    ss_read  <= 0;
    m1_l     <= z80_m1_n;
    cnt      <= cnt + 1'd1;

    case ( state )
        SST_IDLE: begin
            hold68 <= 0; holdz80 <= 0; holdsnd <= 0; cpu_execute <= 0; irq7 <= 0; reset68 <= 0;
            resetz80 <= 0; dirset <= 0; mute <= 0; aux_en <= 0; rp_go <= 0;
            cnt <= 0;
            if ( do_save && !reset ) begin
                hold68 <= 1;
                state  <= SST_SAVE_STOP68;
            end else if ( do_restore && !reset ) begin
                hold68 <= 1; holdz80 <= 1; holdsnd <= 1; mute <= 1;
                state  <= SST_RST_STOP;
            end
        end

        // 68000 frozen; the Z80 runs to the start of its next opcode fetch
        SST_SAVE_STOP68: begin
            if ( cnt == 16'd8 ) begin cnt <= 0; state <= SST_SAVE_STOPZ80; end
        end

        SST_SAVE_STOPZ80: begin
            if ( ( m1_l && !z80_m1_n ) || ( &cnt ) ) begin
                holdz80 <= 1; holdsnd <= 1;
                cpu_execute <= 1; irq7 <= 1;
                state <= SST_SAVE_IRQ;
            end
        end

        // 68000 runs into the level-7 interrupt
        SST_SAVE_IRQ: begin
            if ( !cpu_as_n && ( cpu_fc == 3'b111 ) && ( cpu_a[3:1] == 3'b111 ) ) begin
                irq7  <= 0;
                state <= SST_SAVE_SSP;
            end
        end

        // handler pushes the registers and writes SSP to $3F0000
        SST_SAVE_SSP: begin
            if ( !cpu_as_n && !cpu_rw && !cpu_uds_n && !cpu_lds_n && handler_hit && ( cpu_a[4:1] == 4'd0 ) )
                saved_ssp[31:16] <= cpu_dout;
            if ( !cpu_as_n && !cpu_rw && !cpu_uds_n && !cpu_lds_n && handler_hit && ( cpu_a[4:1] == 4'd1 ) ) begin
                saved_ssp[15:0] <= cpu_dout;
                cpu_execute <= 0;
                cnt <= 0;
                state <= SST_SAVE_SETTLE;
            end
        end

        SST_SAVE_SETTLE: begin
            if ( cnt == 16'd8 ) begin aux_en <= 1; ss_write <= 1; state <= SST_SAVE_WRITE; end
        end

        SST_SAVE_WRITE: begin
            if ( !ss_busy && !ss_write ) begin aux_en <= 0; cnt <= 0; state <= SST_SAVE_RELEASE; end
        end

        SST_SAVE_RELEASE: begin
            if ( cnt == 16'd8 ) begin cpu_execute <= 1; state <= SST_SAVE_EXIT; end
        end

        // handler pops the registers and returns
        SST_SAVE_EXIT: begin
            if ( prog_fetch_out ) state <= SST_IDLE;
        end

        // everything frozen, Z80 in reset; chunks from DDR
        SST_RST_STOP: begin
            resetz80 <= 1;
            if ( cnt == 16'd8 ) begin aux_en <= 1; ss_read <= 1; state <= SST_RST_READ; end
        end

        SST_RST_READ: begin
            if ( !ss_busy && !ss_read ) begin aux_en <= 0; holdsnd <= 0; rp_go <= 1; state <= SST_RST_REPLAY; end
        end

        SST_RST_REPLAY: begin
            if ( rp_done ) begin holdsnd <= 1; rp_go <= 0; resetz80 <= 0; cnt <= 0; state <= SST_RST_Z80; end
        end

        // Z80 registers loaded with DIRSet while its clock enables are stopped
        SST_RST_Z80: begin
            dirset <= ( cnt >= 16'd4 ) && ( cnt < 16'd12 );
            if ( cnt == 16'd16 ) begin
                reset68 <= 1; cpu_execute <= 1; cnt <= 0;
                state <= SST_RST_68K_RESET;
            end
        end

        // 68000 reset with SSP = saved stack, PC = handler restart point
        SST_RST_68K_RESET: begin
            if ( ce_cpu ) begin
                if ( cnt == 16'd64 ) begin reset68 <= 0; state <= SST_RST_68K_RUN; end
            end else begin
                cnt <= cnt;
            end
        end

        SST_RST_68K_RUN: begin
            if ( prog_fetch_out ) state <= SST_IDLE;
        end

        default: state <= SST_IDLE;
    endcase

    if ( reset ) state <= SST_IDLE;
end

endmodule
