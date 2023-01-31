/* myRSP packetizer module */
/* myRSP (Realtime Streaming Protocol) is my original streaming protocol 
* chop raw camera output by MTU & attach header, then output 
* !! myRSP is NOT COMPATIBLE WITH RTSP !! 
* Header including scene ID and row ID */

/*
* |   2 Byte    |   2 Byte  |  2 Byte   | 
* | scene index | row_index | col_index | PAYLOAD */

/* Inbound : raw camera module output (AXI-Stream FIFO) 
* Outbound: myRSP packet (usually encupseled by UDP) (AXI-Stream) 
* these AXI-Stream obey to valid-then-ready model */

module myRSP_packetizer #(
    /* must match these parameters to OV2640 settings */
    parameter integer PIX_DLEN = 8,
    parameter integer MAX_PACKET_LENGTH = 1400
)(
    input wire clk,
    input wire rst_n,

    // Inbound : raw Camera module output (AXI-Stream FIFO)
    input wire [PIX_DLEN-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output reg s_axis_tready,
    input wire s_axis_tlast, // line delimiter
    input wire s_axis_tuser, // scene delimiter
    
    // Outbound : myRSP-header (AXI-Stream)
    output reg m_axis_hdr_valid,
    input wire m_axis_hdr_ready,
    output reg [15:0] m_axis_hdr_length,

    // Outbound : myRSP-packet (AXI-Stream)
    output reg [7:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input wire m_axis_tready,
    output reg m_axis_tlast,
    output wire m_axis_tuser
);

reg [1:0] STATE_reg, STATE_next;
localparam S_IDLE = 2'd0,
    S_HEADER = 2'd1,
    S_READ_LINE = 2'd2,
    S_ASSERT_HEADER = 2'd3;

/* IO signal */
reg [7:0] m_axis_tdata_next;
reg m_axis_tvalid_next;
reg m_axis_tlast_next;
reg m_axis_hdr_valid_next;
reg [15:0] m_axis_hdr_length_next;
// pseudo signal, this signal should not used next stage */
reg __m_axis_tuser_next, __m_axis_tuser;
assign m_axis_tuser = 1'b0;

/* general purpose counter */
reg [15:0] cnt_reg, cnt_next;

/* local signal */
reg [15:0] scene_id_reg, scene_id_next;
reg [15:0] row_id_reg, row_id_next;
reg [15:0] col_id_reg, col_id_next;
reg [47:0] header_reg, header_next;

always @(*)
begin
    /* default value */
    STATE_next = STATE_reg;
    cnt_next = cnt_reg;
    scene_id_next = scene_id_reg;
    row_id_next = row_id_reg;
    col_id_next = col_id_reg;
    header_next = 48'b0;
    s_axis_tready = 0; // wire
    m_axis_tdata_next = 0;
    m_axis_tvalid_next = 0;
    m_axis_tlast_next = 0;
    __m_axis_tuser_next = 0;
    m_axis_hdr_valid_next = 0;
    m_axis_hdr_length_next = 0; // entire packet length

    case (STATE_reg)
        S_IDLE: // wait for valid data prepared
        begin
            cnt_next = 0;
            if (s_axis_tvalid) begin // valid data has be prepared
                header_next = 
                {scene_id_reg[7:0], scene_id_reg[15:8], 
                row_id_reg[7:0], row_id_reg[15:8], 
                col_id_reg[7:0], col_id_reg[15:8]};
                STATE_next = S_HEADER;
            end
        end
        
        S_HEADER: // attach header on each line data.
        begin
            m_axis_tdata_next  = header_reg[47:40];
            header_next = header_reg << 8;
            m_axis_tvalid_next = 1'b1;
            if (m_axis_tready) begin // prepare next data
                cnt_next = cnt_reg + 1'b1;
                if (cnt_reg >= 5) begin
                    STATE_next = S_READ_LINE;
                end
            end
        end
        
        S_READ_LINE: // transfer s_axis to m_axis
        begin
            m_axis_tdata_next  = s_axis_tdata;
            m_axis_tvalid_next = s_axis_tvalid;
            m_axis_tlast_next  = s_axis_tlast;
            __m_axis_tuser_next  = s_axis_tuser;
            if (m_axis_tready || !m_axis_tvalid) begin
            // output is ready or currently not valid, transfer data to output
                s_axis_tready = 1;
                if (m_axis_tvalid) begin
                    if (__m_axis_tuser) begin // end of scene
                        m_axis_tvalid_next = 1'b0;
                        s_axis_tready = 0;
                        scene_id_next = scene_id_reg + 1'b1; // incr. scene Id
                        col_id_next = 0;
                        row_id_next = 0;
                        // STATE_next = S_IDLE;
                        STATE_next = S_ASSERT_HEADER;                         
                    end else if (m_axis_tlast) begin // reach EOL, reset column index
                        m_axis_tvalid_next = 1'b0;
                        s_axis_tready = 0;
                        col_id_next = 0;
                        row_id_next = row_id_reg + 1'b1;
                        // STATE_next = S_IDLE;
                        STATE_next = S_ASSERT_HEADER;                            
                    end else if (cnt_reg >= MAX_PACKET_LENGTH) begin // chop packet by MPL
                        m_axis_tvalid_next = 1'b0;
                        s_axis_tready = 0;
                        // col_id_next = col_id_reg + 1'b1; : TODO
                        // STATE_next = S_IDLE;
                        STATE_next = S_ASSERT_HEADER;                
                    end
                    else begin
                        cnt_next = cnt_reg + m_axis_tready; // if current data accepted , increment
                        col_id_next = col_id_reg + 1;
                    end
                end
            end
        end
        
        S_ASSERT_HEADER: // assert header (only length data currently) for next stage
        begin
            m_axis_hdr_valid_next = 1'b1;
            m_axis_hdr_length_next = cnt_reg; // entire packet length
            if (m_axis_hdr_ready) begin // valid-then-ready
                STATE_next = S_IDLE;
            end
        end

        default:
        begin
            STATE_next = S_IDLE;
        end
    endcase
end

always @(posedge clk)
begin
    if (!rst_n)
    begin
        STATE_reg <= S_IDLE;
        cnt_reg <= 0;
        scene_id_reg <= 0;
        row_id_reg <= 0;
        col_id_reg <= 0;
        header_reg <= 48'b0;
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
        __m_axis_tuser <= 0;
        m_axis_hdr_valid <= 0;
        m_axis_hdr_length <= 0;
    end
    else
    begin
        STATE_reg <= STATE_next;
        cnt_reg <= cnt_next;
        scene_id_reg <= scene_id_next;
        row_id_reg <= row_id_next;
        col_id_reg <= col_id_next;
        header_reg <= header_next;
        m_axis_tdata <= m_axis_tdata_next;
        m_axis_tvalid <= m_axis_tvalid_next;
        m_axis_tlast <= m_axis_tlast_next;
        __m_axis_tuser <= __m_axis_tuser_next;
        m_axis_hdr_valid <= m_axis_hdr_valid_next;
        m_axis_hdr_length <= m_axis_hdr_length_next;
    end
end

endmodule
