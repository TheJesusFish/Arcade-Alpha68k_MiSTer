//============================================================================
//
//  High score save/restore for the Alpha Denshi 68000 core.
//  Entries (MRA rom index 3): 4-byte address, 2-byte length, start byte, end byte (MAME hiscore.dat).
//  Table (MRA nvram index 4): the entries' bytes in order.
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//============================================================================

module hiscore #(parameter MAX_ENTRIES = 4)
(
    input             clk,
    input             reset,
    input             vblank,
    input             osd_open,
    input             autosave,
    input             save_req,

    input             ioctl_download,
    input             ioctl_upload,
    input             ioctl_wr,
    input      [24:0] ioctl_addr,
    input       [7:0] ioctl_dout,
    input      [15:0] ioctl_index,
    output reg  [7:0] ioctl_din,
    output reg        upload_req,
    output            present,

    // 68000 writes
    input             cpu_wr,
    input      [23:1] cpu_a,
    input             cpu_uds_n,
    input             cpu_lds_n,
    input      [15:0] cpu_dout,

    // restore through the RAM aux ports while the 68000 is held
    output reg        hold68,
    input             held,
    output reg        aux_en,
    output reg  [2:0] aux_sel,
    output reg [13:0] aux_addr,
    output reg [15:0] aux_wdata,
    output reg  [1:0] aux_we,
    input             busy_other
);

localparam IDX_ENTRIES = 3, IDX_TABLE = 4;

reg  [23:0] e_addr  [MAX_ENTRIES];
reg  [15:0] e_len   [MAX_ENTRIES];
reg   [7:0] e_start [MAX_ENTRIES];
reg   [7:0] e_end   [MAX_ENTRIES];
reg   [8:0] e_off   [MAX_ENTRIES];
reg   [2:0] n_entries;
reg   [8:0] total;
reg         loaded;

assign present = ( n_entries != 0 );

// entries download
integer i;
always @(posedge clk) begin
    if ( ioctl_download && ioctl_index == 0 ) begin
        n_entries <= 0;
    end else if ( ioctl_download && ioctl_index == IDX_ENTRIES && ioctl_wr && ioctl_addr[24:3] < MAX_ENTRIES ) begin
        case ( ioctl_addr[2:0] )
            3'd1: e_addr[ioctl_addr[4:3]][23:16] <= ioctl_dout;
            3'd2: e_addr[ioctl_addr[4:3]][15:8]  <= ioctl_dout;
            3'd3: e_addr[ioctl_addr[4:3]][7:0]   <= ioctl_dout;
            3'd4: e_len[ioctl_addr[4:3]][15:8]   <= ioctl_dout;
            3'd5: e_len[ioctl_addr[4:3]][7:0]    <= ioctl_dout;
            3'd6: e_start[ioctl_addr[4:3]]       <= ioctl_dout;
            3'd7: begin e_end[ioctl_addr[4:3]]   <= ioctl_dout; n_entries <= ioctl_addr[5:3] + 1'd1; end
            default: ;
        endcase
    end
end

// table offsets
always @(posedge clk) begin
    e_off[0] <= 0;
    for ( i = 1; i < MAX_ENTRIES; i = i + 1 ) e_off[i] <= e_off[i-1] + e_len[i-1][8:0];
    total <= 0;
    case ( n_entries )
        3'd1: total <= e_len[0][8:0];
        3'd2: total <= e_off[1] + e_len[1][8:0];
        3'd3: total <= e_off[2] + e_len[2][8:0];
        3'd4: total <= e_off[3] + e_len[3][8:0];
        default: ;
    endcase
end

////////////////////////////////////////////////////////////////////////////
// tables: live shadow of the game's bytes, saved table from the .nvm

reg  [7:0] shadow [512];
reg  [7:0] saved  [512];
reg  [8:0] sh_waddr, sh_raddr, sv_waddr, sv_raddr;
reg  [7:0] sh_wdata, sv_wdata, sh_q, sv_q;
reg        sh_we, sv_we;

always @(posedge clk) begin
    if ( sh_we ) shadow[sh_waddr] <= sh_wdata;
    sh_q <= shadow[sh_raddr];
end

always @(posedge clk) begin
    if ( sv_we ) saved[sv_waddr] <= sv_wdata;
    sv_q <= saved[sv_raddr];
end

// 68000 byte writes inside an entry -> shadow offset
reg  [23:0] wb_addr[2];
reg   [7:0] wb_data[2];
reg   [1:0] wb_valid;
reg         m_hit;
reg   [8:0] m_off;
reg   [7:0] m_data;

function [9:0] lookup(input [23:0] a);     // {hit, offset}
    integer k;
    reg [23:0] d;
    begin
        lookup = 0;
        for ( k = 0; k < MAX_ENTRIES; k = k + 1 ) begin
            d = a - e_addr[k];
            if ( k < n_entries && a >= e_addr[k] && a < e_addr[k] + e_len[k] )
                lookup = { 1'b1, e_off[k] + d[8:0] };
        end
    end
endfunction

wire [9:0] lk = lookup( wb_valid[0] ? wb_addr[0] : wb_addr[1] );

always @(posedge clk) begin
    m_hit <= 0;
    if ( cpu_wr ) begin
        wb_addr[0]  <= { cpu_a, 1'b0 };
        wb_data[0]  <= cpu_dout[15:8];
        wb_addr[1]  <= { cpu_a, 1'b1 };
        wb_data[1]  <= cpu_dout[7:0];
        wb_valid    <= { !cpu_lds_n, !cpu_uds_n };
    end else if ( wb_valid[0] ) begin
        { m_hit, m_off } <= lk;
        m_data       <= wb_data[0];
        wb_valid[0]  <= 0;
    end else if ( wb_valid[1] ) begin
        { m_hit, m_off } <= lk;
        m_data       <= wb_data[1];
        wb_valid[1]  <= 0;
    end
end

////////////////////////////////////////////////////////////////////////////
// check / restore / save

typedef enum bit [3:0] { HS_WAIT, HS_CHECK_A, HS_CHECK_B, HS_CHECK_C, HS_IDLE, HS_HOLD, HS_RESTORE, HS_RESTORE_W,
                         HS_RELEASE, HS_DONE, HS_COPY } hs_state_t;
hs_state_t st = HS_WAIT;

reg         vbl_l, osd_l, save_l, reset_l;
reg   [5:0] frames;
reg   [2:0] ce;               // entry being checked / restored
reg         ok_all;
reg   [8:0] k;                // table byte
reg  [15:0] b;                // byte within entry
reg   [3:0] dly;
reg         table_ok;         // check bytes have matched since the last reset
reg         restored;
reg   [7:0] ck_start;

wire [23:0] rs_addr = e_addr[ce] + b;
wire        romdl   = ioctl_download && ( ioctl_index == 0 );

always @(posedge clk) begin
    vbl_l   <= vblank;
    osd_l   <= osd_open;
    save_l  <= save_req;
    reset_l <= reset;
    sh_we   <= 0;
    sv_we   <= 0;
    aux_we  <= 0;
    upload_req <= 0;

    // saved table from the .nvm
    if ( ioctl_download && ioctl_index == IDX_TABLE && ioctl_wr && ioctl_addr < 512 ) begin
        sv_we    <= 1;
        sv_waddr <= ioctl_addr[8:0];
        sv_wdata <= ioctl_dout;
        loaded   <= 1;
    end

    // upload serves the live table and keeps it as the saved one
    if ( ioctl_upload && ioctl_index == IDX_TABLE ) begin
        sh_raddr  <= ioctl_addr[8:0];
        ioctl_din <= sh_q;
        if ( ioctl_addr[8:0] != 0 ) begin
            sv_we    <= 1;
            sv_waddr <= ioctl_addr[8:0] - 1'd1;
            sv_wdata <= sh_q;
        end
    end

    // shadow from game writes
    if ( m_hit ) begin
        sh_we    <= 1;
        sh_waddr <= m_off;
        sh_wdata <= m_data;
    end

    // save on OSD open (autosave) or on request, only while the table is the game's
    if ( ( autosave && osd_open && !osd_l ) || ( save_req && !save_l ) ) begin
        if ( present && ( table_ok || restored ) ) upload_req <= 1;
    end

    if ( !( ioctl_upload && ioctl_index == IDX_TABLE ) ) case ( st )
        HS_WAIT: begin
            hold68 <= 0; aux_en <= 0;
            if ( vblank && !vbl_l ) begin
                if ( frames != 6'd30 ) frames <= frames + 1'd1;
                else begin ce <= 0; ok_all <= 1; st <= HS_CHECK_A; end
            end
        end

        // per entry: first byte == start, last byte == end
        HS_CHECK_A: begin
            if ( ce == n_entries ) begin
                if ( ok_all && present ) table_ok <= 1;
                if ( ok_all && present && loaded && !restored ) st <= HS_HOLD;
                else st <= HS_IDLE;
            end else begin
                sh_raddr <= e_off[ce];
                dly <= 0;
                st <= HS_CHECK_B;
            end
        end

        HS_CHECK_B: begin
            dly <= dly + 1'd1;
            if ( dly == 4'd2 ) begin
                ck_start <= sh_q;
                sh_raddr <= e_off[ce] + e_len[ce][8:0] - 1'd1;
                dly <= 0;
                st <= HS_CHECK_C;
            end
        end

        HS_CHECK_C: begin
            dly <= dly + 1'd1;
            if ( dly == 4'd2 ) begin
                if ( ck_start != e_start[ce] || sh_q != e_end[ce] ) ok_all <= 0;
                ce <= ce + 1'd1;
                st <= HS_CHECK_A;
            end
        end

        HS_IDLE: begin
            if ( vblank && !vbl_l ) begin ce <= 0; ok_all <= 1; st <= HS_CHECK_A; end
        end

        // hold the 68000, then write the saved bytes to the game RAM and the shadow
        HS_HOLD: begin
            if ( !busy_other ) hold68 <= 1;
            if ( hold68 && held ) begin
                aux_en <= 1;
                k <= 0; ce <= 0; b <= 0;
                sv_raddr <= 0;
                dly <= 0;
                st <= HS_RESTORE;
            end
        end

        HS_RESTORE: begin
            dly <= dly + 1'd1;
            if ( dly == 4'd2 ) begin
                aux_sel   <= ( rs_addr[23:16] == 8'h04 ) ? 3'd0 : ( rs_addr[23:16] == 8'h20 ) ? 3'd1 :
                             ( rs_addr[23:16] == 8'h10 ) ? 3'd2 : 3'd3;
                aux_addr  <= rs_addr[14:1];
                aux_wdata <= { sv_q, sv_q };
                aux_we    <= rs_addr[0] ? 2'b01 : 2'b10;
                sh_we     <= 1;
                sh_waddr  <= k;
                sh_wdata  <= sv_q;
                dly <= 0;
                st <= HS_RESTORE_W;
            end
        end

        HS_RESTORE_W: begin
            dly <= dly + 1'd1;
            if ( dly == 4'd2 ) begin
                dly <= 0;
                k <= k + 1'd1;
                sv_raddr <= k + 1'd1;
                if ( b + 1'd1 == e_len[ce] ) begin
                    b <= 0;
                    ce <= ce + 1'd1;
                    if ( ce + 1'd1 == n_entries ) st <= HS_RELEASE;
                    else st <= HS_RESTORE;
                end else begin
                    b <= b + 1'd1;
                    st <= HS_RESTORE;
                end
            end
        end

        HS_RELEASE: begin
            aux_en <= 0;
            dly <= dly + 1'd1;
            if ( dly == 4'd4 ) begin
                hold68 <= 0;
                restored <= 1;
                st <= HS_DONE;
            end
        end

        HS_DONE: begin
            if ( vblank && !vbl_l ) begin ce <= 0; ok_all <= 1; st <= HS_CHECK_A; end
        end

        // after a game reset, keep the table the game had (restored or played) as the one to restore
        HS_COPY: begin
            dly <= dly + 1'd1;
            if ( dly == 4'd2 ) begin
                sv_we    <= 1;
                sv_waddr <= k;
                sv_wdata <= sh_q;
                dly <= 0;
                k <= k + 1'd1;
                sh_raddr <= k + 1'd1;
                if ( k + 1'd1 == total ) begin loaded <= 1; st <= HS_WAIT; end
            end
        end

        default: st <= HS_WAIT;
    endcase

    if ( reset && !reset_l ) begin
        hold68 <= 0; aux_en <= 0; frames <= 0; table_ok <= 0;
        if ( ( restored || table_ok ) && !romdl ) begin
            restored <= 0;
            k <= 0; sh_raddr <= 0; dly <= 0;
            st <= HS_COPY;
        end else begin
            st <= HS_WAIT;
        end
    end else if ( reset ) begin
        frames <= 0;
    end

    // a new ROM load starts from the files it brings
    if ( romdl ) begin
        restored <= 0; table_ok <= 0; loaded <= 0; hold68 <= 0; aux_en <= 0;
        st <= HS_WAIT;
    end
end

endmodule
