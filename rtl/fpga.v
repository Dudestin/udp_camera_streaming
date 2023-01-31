`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA top-level module
 */
module fpga (
    /*
     * Clock: 24 MHz
     * Reset: Push button, active low
     */
    input  wire       clk,
    input  wire       arst_n,

    /*
     * GPIO
     */
    output wire [2:0] RGB_LED,

    /*
     * Ethernet: 100BASE-T RMII
     */
    input  wire       PHY_REF_CLK,
    input  wire       PHY_CRSDV,
    input  wire [1:0] PHY_RXD,
    output wire [1:0] PHY_TXD,
    output wire       PHY_TXEN,
    output wire       PHY_RESETB,

	/*
	 * OV2640: Camera
	 */
	input wire  [7:0] CSI_D,
	input wire  CSI_PCLK,
	output wire CSI_XCLK,
	input wire  CSI_HREF,
	input wire  CSI_VSYNC,
	output wire CSI_PWDN,
	output wire CSI_RSTB,
	
	output wire CSI_SOIC,
	inout wire CSI_SOID,	

    /*
     * UART: 500000 bps, 8N1
     */
    input  wire       uart_rxd,
    output wire       uart_txd
    
    // LCD backlight stepup converter
    //output wire zLCD_PWM
);

// assign zLCD_PWM = 1'b0;

// Clock and reset
// Internal 125 MHz clock
wire clk_int;
wire clk_soc;
wire clk_cam;
wire clk_sccb;
wire rst_int;
wire rst_soc;
wire rst_cam;
wire rst_sccb;

wire pll_rst = ~arst_n;
wire pll_locked;

assign CSI_XCLK = clk_cam; // 12 MHz
assign CSI_PWDN = 1'b0;
assign CSI_RSTB = 1'b1;
assign RGB_LED = {CNT[26], CNT[25], CNT[24]};

reg [26:0] CNT;
always @(posedge CSI_PCLK)
begin
	CNT <= CNT + 1'b1;
end

// PLL instance
// 24 MHz in, 100 MHz out
// Divide by 8 to get output frequency of 125 MHz
// Divide by 40 to get output frequency of 25 MHz

pll_sys_clk pll_sys_clk_inst (
    .refclk(clk),
    .reset(pll_rst),
    .clk0_out(clk_int), // 100 MHz (Core)
    .clk1_out(clk_soc), // 50 MHz (SoC)
    .clk2_out(clk_cam), // 12 MHz (OV2640)
    .clk3_out(clk_sccb), // 4 MHz (SOIC)
    .extlock(pll_locked)
);

// assign RGB_LED = {~pll_locked, ~pll_locked, ~pll_locked};

sync_reset #(
    .N(4)
)
sync_reset_inst (
    .clk(clk_int),
    .rst(~pll_locked),
    .out(rst_int)
);

sync_reset #(
    .N(4)
)
sync_reset_soc_inst (
    .clk(clk_soc),
    .rst(~pll_locked),
    .out(rst_soc)
);

sync_reset #(
    .N(4)
)
sync_reset_cam_inst (
    .clk(clk_cam),
    .rst(~pll_locked),
    .out(rst_cam)
);

sync_reset #(
    .N(4)
)
sync_reset_sccb_inst (
    .clk(clk_sccb),
    .rst(~pll_locked),
    .out(rst_sccb)
);

wire       phy_rx_clk;
wire [3:0] phy_rxd;
wire       phy_rx_dv;
wire       phy_rx_er = 1'b0;
wire       phy_tx_clk;
wire [3:0] phy_txd;
wire       phy_tx_en;
wire       phy_col = 1'b0;
wire       phy_crs;
wire       phy_reset_n;

assign PHY_RESETB = phy_reset_n;

fpga_core core_inst (
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    .clk(clk_int),
    .rst(rst_int),
    /*
     * GPIO
     */
    .RGB_LED(),
    
    /*
     * CAMERA
     */
    .CSI_PCLK(CSI_PCLK),
    .CSI_D(CSI_D),
    .CSI_HREF(CSI_HREF),
    .CSI_VSYNC(CSI_VSYNC),
    .CSI_RSTB(CSI_RSTB),
    
    /*
     * Ethernet: 100BASE-T MII
     */
    .phy_rx_clk(phy_rx_clk),
    .phy_rxd(phy_rxd),
    .phy_rx_dv(phy_rx_dv),
    .phy_rx_er(phy_rx_er),
    .phy_tx_clk(phy_tx_clk),
    .phy_txd(phy_txd),
    .phy_tx_en(phy_tx_en),
    .phy_col(phy_col),
    .phy_crs(phy_crs),
    .phy_reset_n(phy_reset_n),
    /*
     * UART: 115200 bps, 8N1
     */
    .uart_rxd(),
    .uart_txd()// assign CSI_RSTB = ~rst_cam;
);

/* Convert MII with RMII */
rmii_phy_if phy_if_core(
    // reset, active low
    .rstn_async(~rst_int),
    // speed mode: 0:10M, 1:100M, must be correctly specified
    .mode_speed(1'b1),
    // MII interface connect to MAC
    .mac_mii_crs(phy_crs),
    .mac_mii_rxrst(),     // optional reset signal to MAC
    .mac_mii_rxc(phy_rx_clk),
    .mac_mii_rxdv(phy_rx_dv),
    .mac_mii_rxer(),
    .mac_mii_rxd(phy_rxd),
    .mac_mii_txrst(),     // optional reset signal to MAC
    .mac_mii_txc(phy_tx_clk),
    .mac_mii_txen(phy_tx_en),
    .mac_mii_txer(1'b0),
    .mac_mii_txd(phy_txd),
    // RMII interface connect to PHY
    .phy_rmii_ref_clk(PHY_REF_CLK),  // 50MHz required
    .phy_rmii_crsdv(PHY_CRSDV),
    .phy_rmii_rxer(1'b0),     // rxer is optional for RMII
    .phy_rmii_rxd(PHY_RXD),
    .phy_rmii_txen(PHY_TXEN),
    .phy_rmii_txd(PHY_TXD)
);

/* OV2640 config module */
wire sda_oe;
wire sda;
wire sda_in;
wire scl;
assign CSI_SOID = (sda_oe) ? sda : 1'bz;
assign sda_in = CSI_SOID;
assign CSI_SOIC = scl;
camera_init camera_init_impl (
	.clk(clk_sccb),
	.reset_n(~rst_sccb),
	.ready(),
	
	.sda_oe(sda_oe),
	.sda(sda),
	.sda_in(sda_in),
	.scl(scl)
);
endmodule

`resetall
