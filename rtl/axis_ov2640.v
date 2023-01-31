/* Camera (OV2640) data receive module */
/* Inbound : OV2640 interface,
*  Outbound: AXI-Stream ASYNC FIFO interface */

module axis_ov2640 #(
	parameter integer IMAGE_HEIGHT = 600
)(
    input wire arst_n,

    input wire enable, // work on when asserted
    output wire busy,  // assert when busy

    /* inbound : OV2640 interface */
    input wire PCLK,   // Pixel clock
    input wire [7:0] DIN,
    input wire HREF,
    input wire VSYNC,
    output wire RESETB, // active low

    /* outbound : AXI-Stream interface, assume ready asserted constantly.
    * usually insert AXI-Stream FIFO next stage to achieve this condition,
    * and need to be clk faster than PCLK (Supplier) */
    output wire [7:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input  wire m_axis_tready,
    output wire m_axis_tlast, // end of line
    output wire m_axis_tuser  // end of scene
);

/* OV2640 RESETB SYSTEM */
reg [5:0] cam_rst_cnt = 0;
assign RESETB = &cam_rst_cnt;
always @(posedge PCLK or negedge arst_n)
begin
    if (!arst_n) begin
        cam_rst_cnt <= 0;
    end else begin
        cam_rst_cnt <= cam_rst_cnt + ~RESETB;
    end
end

/* core module, work on PCLK */
wire core_enable;
sync_2ff sync_enable(.clk(PCLK), .din(enable), .dout(core_enable));
wire core_busy;
sync_2ff sync_busy(.clk(clk), .din(core_busy), .dout(busy));

axis_ov2640_core #(
	.IMAGE_HEIGHT(IMAGE_HEIGHT)
) core_impl (
    .enable(core_enable),
    .busy(core_busy),
    /* OV2640 (Camera) interface */
    .PCLK (PCLK),
    .DIN  (DIN),
    .HREF (HREF),
    .VSYNC(VSYNC),
    .RESETB(RESETB),
    /* axis master interface */
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast (m_axis_tlast), // line delimiter
    .m_axis_tuser (m_axis_tuser)  // scene delimiter
);

endmodule
