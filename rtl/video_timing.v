
module video_timing
(
    input       clk,
    input       clk_pix,
    input       reset,

    input  [2:0] pcb,
    
    input  signed [3:0] hs_offset,
    input  signed [3:0] vs_offset,

    input  signed [3:0] hs_width,
    input  signed [3:0] vs_width,

    output [8:0] hc,
    output [8:0] vc,

    output reg  hsync,
    output reg  vsync,
    
    output reg  hbl,
    output reg  vbl 
);

wire [8:0] h_ofs = 0;
wire [8:0] HBL_START  = 256 ;
wire [8:0] HBL_END    = 0 ;
wire [8:0] HTOTAL     = 383;

wire [8:0] v_ofs = 0;
wire [8:0] VBL_START  = 241 ;
wire [8:0] VBL_END    = 17 ;
wire [8:0] VTOTAL     = 263 ;

// sync adjustments are signed (-8..+7): pulse start, length of at least one, end wrapped at the line / frame total
wire signed [10:0] hs_start_s = 11'sd297 + hs_offset;
wire signed [10:0] hs_len_s   = 11'sd32  + hs_width;
wire signed [10:0] vs_start_s = 11'sd254 + vs_offset;
wire signed [10:0] vs_len_s   = 11'sd8   + vs_width;

wire  [9:0] hs_len   = ( hs_len_s < 11'sd1 ) ? 10'd1 : hs_len_s[9:0];
wire  [9:0] vs_len   = ( vs_len_s < 11'sd1 ) ? 10'd1 : vs_len_s[9:0];
wire  [9:0] hs_end_r = hs_start_s[9:0] + hs_len;
wire  [9:0] vs_end_r = vs_start_s[9:0] + vs_len;

wire  [9:0] hs_end_w = ( hs_end_r > { 1'b0, HTOTAL } ) ? hs_end_r - ( { 1'b0, HTOTAL } + 10'd1 ) : hs_end_r;
wire  [9:0] vs_end_w = ( vs_end_r > { 1'b0, VTOTAL } ) ? vs_end_r - ( { 1'b0, VTOTAL } + 10'd1 ) : vs_end_r;

wire [8:0] HS_START   = hs_start_s[8:0];
wire [8:0] HS_END     = hs_end_w[8:0];
wire [8:0] VS_START   = vs_start_s[8:0];
wire [8:0] VS_END     = vs_end_w[8:0];


reg [8:0] v;
reg [8:0] h;

assign vc = v - v_ofs;
assign hc = h - h_ofs;

always @ (posedge clk) begin
    if (reset) begin
        h <= 0;
        v <= 0;

        hbl <= 0;
        vbl <= 0;

        hsync <= 0;
        vsync <= 0;
    end else if ( clk_pix == 1 ) begin 
        // counter
        if (h == HTOTAL) begin
            h <= 0;
            v <= v + 1'd1;

            if ( v == VTOTAL ) begin
                v <= 0;
            end
        end else begin
            h <= h + 1'd1;
        end

        // h signals
        if ( h == HBL_START ) begin
            hbl <= 1;
        end else if ( h == HBL_END ) begin
            hbl <= 0;
        end

        // v signals
        if ( v == VBL_START ) begin
            vbl <= 1;
        end else if ( v == VBL_END ) begin
            vbl <= 0;
        end
   
        if ( v == (VS_START ) ) begin
            vsync <= 1;
        end else if ( v == (VS_END ) ) begin
            vsync <= 0;
        end

        if ( h == (HS_START ) ) begin
            hsync <= 1;
        end else if ( h == (HS_END ) ) begin
            hsync <= 0;
        end
    end

end

endmodule

