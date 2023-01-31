`timescale 1ns/1ps

/* Camera (OV2640) data receive core module */
/* Inbound : OV2640 interface,
*  Outbound: ASYNC FIFO interface */

module axis_ov2640_core #(
    parameter integer IMAGE_HEIGHT = 300
)(
    input wire enable, // work on when asserted
    output wire busy,  // assert when busy

    /* inbound : OV2640 interface */
    input wire PCLK,      // Pixel clock
    input wire [7:0] DIN,
    input wire HREF,
    input wire VSYNC,
    input wire RESETB,

    /* outbound : AXI-Stream interface, assume ready asserted constantly.
    * usually insert AXI-Stream FIFO next stage to achieve this condition,
    * and need to be "Consumer" must be faster clock than PCLK (Supplier) */
    output reg [7:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input  wire m_axis_tready,
    output reg m_axis_tlast, // end of line
    output reg m_axis_tuser  // end of scene
);

/* IO-signal */
reg [7:0] m_axis_tdata_next;
reg m_axis_tvalid_next;
reg m_axis_tuser_next;

/* Statemachine */
reg STATE_reg, STATE_next;
localparam S_IDLE = 1'd0,
    S_READ = 1'd1;
assign busy = (STATE_reg != S_IDLE); // busy flag

/* general purpose counter */
reg [16:0] cnt_reg, cnt_next;

/* detect negedge of HREF (delimit the line)*/
reg HREF_lat;
always @(posedge PCLK)
begin
    if (!RESETB)
        HREF_lat <= 1'b0;
    else
        HREF_lat <= HREF;
end
assign HREF_negedge = (~HREF & HREF_lat);

/* detect posedge of VSYNC (delimit the scene)*/
reg VSYNC_lat;
always @(posedge PCLK)
begin
    if (!RESETB)
        VSYNC_lat <= 1'b0;
    else
        VSYNC_lat <= VSYNC;
end
assign VSYNC_posedge = (VSYNC  & ~VSYNC_lat);

always @(*)
begin
    // default values
    m_axis_tdata_next = m_axis_tdata;
    m_axis_tvalid_next = m_axis_tvalid;
    m_axis_tlast = 1'b0;
    m_axis_tuser = 1'b0;
    STATE_next = STATE_reg;
    cnt_next = cnt_reg;

    case (STATE_reg)
        S_IDLE:
        begin
            m_axis_tdata_next  = 0;
            m_axis_tvalid_next = 0;
            m_axis_tlast = 0;
            m_axis_tuser = 0;
            STATE_next = (VSYNC_posedge && enable) ? S_READ : S_IDLE;
            cnt_next = 0;
        end

        S_READ:
        begin
            m_axis_tdata_next  = HREF ? DIN : 0;
            m_axis_tvalid_next = HREF; // valid data is provided
            m_axis_tlast = HREF_negedge; // end of the lines
            m_axis_tuser = (cnt_reg >= IMAGE_HEIGHT-1) & HREF_negedge; // end of the scene
            // STATE_next = (cnt_reg >= IMAGE_HEIGHT) ? S_IDLE : S_READ;
            STATE_next = m_axis_tuser ? S_IDLE : S_READ;
            cnt_next = cnt_reg + HREF_negedge;
        end

        default: // undefined state
        begin
            STATE_next = S_IDLE;
        end
    endcase
end

always @(posedge PCLK)
begin
    if (!RESETB)
    begin
        m_axis_tdata <= 0;
        m_axis_tvalid <= 0;
        STATE_reg <= S_IDLE; 
        cnt_reg <= 0;
    end
    else
    begin
        m_axis_tdata <= m_axis_tdata_next;
        m_axis_tvalid <= m_axis_tvalid_next;
        STATE_reg <= STATE_next;
        cnt_reg <= cnt_next;
    end
end

endmodule
