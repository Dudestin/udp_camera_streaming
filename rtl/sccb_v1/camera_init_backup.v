module camera_init (

	input clk,
	input reset_n,

	output reg ready,

	output wire sda_oe,
	output wire sda,
	input wire sda_in,
	output scl
);

parameter REGS_TO_INIT = 200;

localparam CAMERA_INIT_1 = 11;
localparam CAMERA_INIT_2 = 12;
localparam CAMERA_INIT_3 = 13;
localparam CAMERA_INIT_4 = 14;
localparam CAMERA_INIT_5 = 15;
localparam CAMERA_INIT_6 = 16;
localparam CAMERA_INIT_7 = 17;
localparam CAMERA_IDLE = 18;

localparam CONTROL_REG = 3'b000;
localparam SLAVE_ADDRESS = 3'b001;
localparam SLAVE_REG_ADDRESS = 3'b010;
localparam SLAVE_DATA_1 = 3'b011;
localparam SLAVE_DATA_2 = 3'b100;

//I2C//////////////////////////////////////////
reg[7:0] data_in_bus = 0;
reg [2:0] reg_address = 0;
reg bus_write = 0;
wire ready_out;
wire success_out;

i2c_module i2c_write_module(.clk(clk), .reset_n(reset_n), .scl_out(scl), 
						.writedata(data_in_bus), .address(reg_address),
						.write(bus_write), .ready(ready_out), .success_out(success_out), .sda_in(sda_in), .sda(sda), .sda_oe(sda_oe)  );

/////////////////////////////////////////

wire[7:0] regs_addr;
wire[7:0] data_to_write;
reg[7:0] counter = 0;

reg[7:0] state_next;


wire [15:0] regs_data = 
	counter == 0 ? 16'hff_01: // change sheet 1
	counter == 1 ? 16'h12_80: // COM7: system reset
	
	counter == 2 ? 16'hff_00: // change sheet 0
	counter == 3 ? 16'h2c_ff: // unknown
	counter == 4 ? 16'h2e_df: // unknown
	/* SHEET 1 */
	counter == 5 ? 16'hff_01:
	counter == 6 ? 16'h3c_32: // unknown
	
	counter == 7 ? 16'h11_00: // CRKRC: clock rate control
	counter == 8 ? 16'h09_02: // COM2: output drive select
	counter == 9 ? 16'h04_d8: // *REG04* 
	counter == 10 ? 16'h13_e5: // COM8
	counter == 11 ? 16'h14_48: // COM9: AGC gain
	counter == 12 ? 16'h2c_0c: // unknown
	counter == 13 ? 16'h33_78: // unknown
	counter == 14 ? 16'h3a_33: // unknown
	counter == 15 ? 16'h3b_fb: // unknwon
	counter == 16 ? 16'h3e_00: // unknwon
	counter == 17 ? 16'h43_11: // unkwown
	counter == 18 ? 16'h16_10: // unknown
	
	counter == 19 ? 16'h39_92: // unknown
	
	counter == 20 ? 16'h35_da: // unknown
	counter == 21 ? 16'h22_1a: // unknown
	counter == 22 ? 16'h37_c3: // unknown
	counter == 23 ? 16'h23_00: // unknown
	counter == 24 ? 16'h34_c0: // ARCOM2: unknown bit
	counter == 25 ? 16'h36_1a: // unknown
	counter == 26 ? 16'h06_88: // unknown
	counter == 27 ? 16'h07_c0: // unknown
	counter == 28 ? 16'h0d_87: // COM4: unknown bit
	counter == 29 ? 16'h0e_41: // unknown
	counter == 30 ? 16'h4c_00: // unknown
	counter == 31 ? 16'h48_00: // COM19: zoom mode vert. window start point 2 LSB
	counter == 32 ? 16'h5b_00: // unknown
	counter == 33 ? 16'h42_03: // unknown
	
	counter == 34 ? 16'h4a_81: // unknown
	counter == 35 ? 16'h21_99: // unknown
	
	counter == 36 ? 16'h24_40: // AEW: AEG/AGC settings
	counter == 37 ? 16'h25_38: // AEB: AEC/AGC settings
	counter == 38 ? 16'h26_82: // VV: fast mode large step range threshold
	counter == 39 ? 16'h5c_00: // unknown
	counter == 40 ? 16'h63_00: // unknown
	counter == 41 ? 16'h46_00: // FLL: Frame length adjustment LSBs
	counter == 42 ? 16'h0c_3c: // COM3: unknown & 50Hz
	
	counter == 43 ? 16'h61_70: // HISTO_LOW: histogram algorithm low level
	counter == 44 ? 16'h62_80: // HISTO_HIGH: Histogram algorithm high level
	counter == 45 ? 16'h7c_05: // unknown
	
	counter == 46 ? 16'h20_80: // unknown
	counter == 47 ? 16'h28_30: // unknown
	counter == 48 ? 16'h6c_00: // unknown
	counter == 49 ? 16'h6d_80: // unknown
	counter == 50 ? 16'h6e_00: // unknown
	counter == 51 ? 16'h70_02: // unknown
	counter == 52 ? 16'h71_94: // unknown
	counter == 53 ? 16'h73_c1: // unknown
	// differ
	counter == 54 ? 16'h3d_34: // unknown
	counter == 55 ? 16'h5a_57: // unknown
	
	counter == 56 ? 16'h12_00: // COM7: UXGA & zoom mode & color bar test
	counter == 57 ? 16'h17_11: // HREFST: horizon. window start pos
	counter == 58 ? 16'h18_75: // HREFEND: horizon. window end pos
	counter == 59 ? 16'h19_01: // VSTRT: vert. window start pos
	counter == 60 ? 16'h1a_97: // VEND : vert. window end pos
	counter == 61 ? 16'h32_36: // REG32: horizon. window start & end pos. LSB
	counter == 62 ? 16'h03_0f: // COM1 : vert. window start & end pos. LSB
	counter == 63 ? 16'h37_40: // unknown
	counter == 64 ? 16'h4f_ca: // BD50: 50Hz Banding AEC 8 LSBs
	counter == 65 ? 16'h50_a8: // BD60: 60Hz Banding AEC 8 LSBs
	counter == 66 ? 16'h5a_23: // unknown
	counter == 67 ? 16'h6d_00: // unknown
	counter == 68 ? 16'h6d_38: // unknown
	/* SHEET 0 */
	counter == 69 ? 16'hff_00:
	counter == 70 ? 16'he5_7f: // unknown
	counter == 71 ? 16'hf9_c0: // MC_BIST: 
	counter == 72 ? 16'h41_24: // unknown
	counter == 73 ? 16'he0_14: // RESET: JPEG & DVP
	counter == 74 ? 16'h76_ff: // unknown
	counter == 75 ? 16'h33_a0: // unknown
	counter == 76 ? 16'h42_20: // unknown
	counter == 77 ? 16'h43_18: // unknown
	counter == 78 ? 16'h4c_00: // unknown
	counter == 79 ? 16'h87_d5: // CTRL3: module enable
	counter == 80 ? 16'h88_3f: // unknown
	counter == 81 ? 16'hd7_03: // unknown
	counter == 82 ? 16'hd9_10: // unknown
	counter == 83 ? 16'hd3_82: // R_DVP_SP: DVP speed control
	
	counter == 84 ? 16'hc8_08: // unknown
	counter == 85 ? 16'hc9_80: // unknown
	
	counter == 86 ? 16'h7c_00: // BPADDR: SDE indirect register access addres
	counter == 87 ? 16'h7d_00: // BPDATA: 
	counter == 88 ? 16'h7c_03:
	counter == 89 ? 16'h7d_48:
	counter == 90 ? 16'h7d_48:
	counter == 91 ? 16'h7c_08:
	counter == 92 ? 16'h7d_20:
	counter == 93 ? 16'h7d_10:
	counter == 94 ? 16'h7d_0e:
	
	counter == 95 ? 16'h90_00: // unknown
	counter == 96 ? 16'h91_0e:
	counter == 97 ? 16'h91_1a:
	counter == 98 ? 16'h91_31:
	counter == 99 ? 16'h91_5a:
	counter == 100 ? 16'h91_69:
	counter == 101 ? 16'h91_75:
	counter == 102 ? 16'h91_7e:
	counter == 103 ? 16'h91_88:
	counter == 104 ? 16'h91_8f:
	counter == 105 ? 16'h91_96:
	counter == 106 ? 16'h91_a3:
	counter == 107 ? 16'h91_af:
	counter == 108 ? 16'h91_c4:
	counter == 109 ? 16'h91_d7:
	counter == 110 ? 16'h91_e8:
	counter == 111 ? 16'h91_20:

	counter == 112 ? 16'h92_00:
	counter == 113 ? 16'h93_06:
	counter == 114 ? 16'h93_e3:
	counter == 115 ? 16'h93_05:
	counter == 116 ? 16'h93_05:
	counter == 117 ? 16'h93_00:
	counter == 118 ? 16'h93_04:
	counter == 119 ? 16'h93_00:
	counter == 120 ? 16'h93_00:
	counter == 121 ? 16'h93_00:
	counter == 122 ? 16'h93_00:
	counter == 123 ? 16'h93_00:
	counter == 124 ? 16'h93_00:
	counter == 125 ? 16'h93_00:
	
	counter == 126 ? 16'h96_00:
	counter == 127 ? 16'h97_08:
	counter == 128 ? 16'h97_19:
	counter == 129 ? 16'h97_02:
	counter == 130 ? 16'h97_0c:
	counter == 131 ? 16'h97_24:
	counter == 132 ? 16'h97_30:
	counter == 133 ? 16'h97_28:
	counter == 134 ? 16'h97_26:
	counter == 135 ? 16'h97_02:
	counter == 136 ? 16'h97_98:
	counter == 137 ? 16'h97_80:
	counter == 138 ? 16'h97_00:
	counter == 139 ? 16'h97_00:
	
	counter == 140 ? 16'hc3_ef: // CTRL1: module enable
	counter == 141 ? 16'ha4_00: // unknown
	counter == 142 ? 16'ha8_00: // unknown
	counter == 143 ? 16'hc5_11: // unknown
	counter == 144 ? 16'hc6_51: // unknown
	counter == 145 ? 16'hbf_80: // unknown
	counter == 146 ? 16'hc7_10: // unknown
	counter == 147 ? 16'hb6_66: // unknown
	counter == 148 ? 16'hb8_a5: // unknown
	counter == 149 ? 16'hb7_64: // unknown
	counter == 150 ? 16'hb9_7c: // unknown
	counter == 151 ? 16'hb3_af: // unknown
	counter == 152 ? 16'hb4_97: // unknown
	counter == 153 ? 16'hb5_ff: // unknown
	counter == 154 ? 16'hb0_c5: // unknown
	counter == 155 ? 16'hb1_94: // unknown
	counter == 156 ? 16'hb2_0f: // unknown
	counter == 157 ? 16'hc4_5c: // unknown
	counter == 158 ? 16'hc0_c8: // HSIZE8: Image Horizontal Size HSIZE[10:3]
	counter == 159 ? 16'hc1_96: // VSIZE8: Image Vertical Size VSIZE[10:3]
	counter == 160 ? 16'h8c_00: // SIZEL:  {HSIZE[11], HSIZE[2:0], VSIZE[2:0]}
	counter == 161 ? 16'h86_3d: // module enable
	counter == 162 ? 16'h50_00: // CTRLI: 
	counter == 163 ? 16'h51_90: // HSIZE: H_SIZE[7:0] (real/4)
	counter == 164 ? 16'h52_2c: // VSIZE: V_SIZE[7:0] (real/4)
	counter == 165 ? 16'h53_00: // XOFFL: OFFSET_X[7:0]
	counter == 166 ? 16'h54_00: // YOFFL: OFFSET_Y[7:0]
	counter == 167 ? 16'h55_88: // VHYX[7:0]
	counter == 168 ? 16'h5a_90: // ZMOW[7:0]
	counter == 169 ? 16'h5b_2c: // ZMOH[7:0]
	counter == 170 ? 16'h5c_05: // ZMHW[1:0]
	counter == 171 ? 16'hd3_02: // R_DVP_SP

	counter == 172 ? 16'hc3_ed: // CTRL1: module enable
	counter == 173 ? 16'h7f_00: // unknown
	
	counter == 174 ? 16'hda_09: // IMAGE_MODE:
	
	counter == 175 ? 16'he5_1f: // unknown
	counter == 176 ? 16'he1_67: // unknown
	counter == 177 ? 16'he0_00: // RESET
	counter == 178 ? 16'hdd_7f: // unknown
	counter == 179 ? 16'h05_00: // R_BYPASS: use DSP
	//Set OV2640 to RGB565 Mode
	counter == 180 ? 16'hff_00:
	counter == 181 ? 16'hda_09: // IMAGE_MODE
	counter == 182 ? 16'hd7_03: // unknown
	counter == 183 ? 16'hdf_02: // unknown
	counter == 184 ? 16'h33_a0: // unknown
	counter == 185 ? 16'h3c_00: // unknown
	counter == 186 ? 16'he1_67: // unknown
	// SHEET 0
	counter == 187 ? 16'hff_01:
	counter == 188 ? 16'he0_00: // unknown
	counter == 189 ? 16'he1_00: // unknown
	counter == 190 ? 16'he5_00: // unknown
	counter == 191 ? 16'hd7_00: // unknown 
	counter == 192 ? 16'hda_00: // unknown
	counter == 193 ? 16'he0_00: // unknown
	//[OV2640_OutSize_Set] width:480 height:272
	counter == 194 ? 16'hff_00:
	counter == 195 ? 16'he0_04: // RESET: DVP
	counter == 196 ? 16'h5a_64: // ZMOW: 64 = 100 (W:400)
	counter == 197 ? 16'h5b_4B: // ZMOH: 4B = 75  (H:300)
	counter == 198 ? 16'h5c_00: // ZMHH: 
	counter == 199 ? 16'he0_00: // RESET
	16'hFF;

//assign regs_addr = 	counter == 0 ? 8'h12 :
//							counter == 1 ? 8'h12 :
//							counter == 2 ? 8'h12 :	
//							counter == 3 ? 8'h40 :
//							counter == 4 ? 8'h58 :
//							counter == 5 ? 8'h1e :
//							counter == 6 ? 8'h3c :
//							8'hFF;
							
//assign data_to_write = 	counter == 0 ? 8'h80 :
//								counter == 1 ? 8'h04 :
//								counter == 2 ? 8'h04 :	
//								counter == 3 ? 8'hd0 :
//								counter == 4 ? 8'h9e :
//								counter == 5 ? 8'h01 :
//								counter == 6 ? 8'h78 :
//								8'hFF;
								
always@(posedge clk)
begin
		if(state_next == CAMERA_IDLE)
			ready <= 1'b1;
		else
			ready <= 1'b0;
end
	
always@(posedge clk)
begin

	if(reset_n == 1'b0)
	begin
		state_next <= CAMERA_INIT_1;	
	end
	else
	begin
		case(state_next)
			
			CAMERA_INIT_1:
				begin 
					state_next <= CAMERA_INIT_2;		
				end
			
			CAMERA_INIT_2:
				begin
						state_next <= CAMERA_INIT_3;
				end
			
			CAMERA_INIT_3:
				begin
					state_next <= CAMERA_INIT_4;
				
				end
				
			CAMERA_INIT_4:
				begin
					state_next <= CAMERA_INIT_7;
				end
			
			//wait until ready_out is set to 0
			CAMERA_INIT_7:
			begin
				if(ready_out == 1'b0)
					state_next <= CAMERA_INIT_5;
			end
				
			CAMERA_INIT_5:
				begin
					if(ready_out == 1'b1)
					begin
						if(success_out == 1'b1)
						begin
							if(counter == REGS_TO_INIT - 1)
							begin
								state_next <= CAMERA_IDLE;
							end
							else
							state_next <= CAMERA_INIT_6;
						end
						else
						state_next <= CAMERA_INIT_2;
					end	
				end
				
			CAMERA_INIT_6:
				begin
					state_next <= CAMERA_INIT_2;
				end
				
			CAMERA_IDLE:
				begin
					state_next <= CAMERA_IDLE;
				end
				
		endcase
	end
end

//always@(posedge clk)
//begin
//	if(state_next == CAMERA_INIT_6)
//		counter <= counter + 1'b1;
//	else
//		counter <= counter;
//	
//end	
//	
always@(posedge clk)
begin
	if(reset_n == 1'b0)
	begin
		reg_address <= 0;
		data_in_bus <= 0;
		bus_write <= 1'b0;
		counter <= 0;
	end
	else
	begin
		case(state_next)
			
			CAMERA_INIT_1:
				begin
					reg_address <= SLAVE_ADDRESS;
					data_in_bus <= 8'h60; // slave address
					bus_write <= 1'b1;
				end
			
			CAMERA_INIT_2:
				begin
					reg_address <= SLAVE_REG_ADDRESS;
					data_in_bus <= regs_data[15:8];
					bus_write <= 1'b1;	
				end
			
			CAMERA_INIT_3:
				begin
					reg_address <= SLAVE_DATA_1;
					data_in_bus <= regs_data[7:0];
					bus_write <= 1'b1;			
				end
				
			CAMERA_INIT_4:
				begin
					reg_address <= CONTROL_REG;
					data_in_bus <= 3'b001;
					bus_write <= 1'b1;
				end
			
			CAMERA_INIT_5:
				begin
					reg_address <= 0;
					data_in_bus <= 0;
					bus_write <= 1'b0;
				end
				
			CAMERA_INIT_6:
				begin
					bus_write <= 1'b0;

					reg_address <= 0;
					data_in_bus <= 0;
					
					counter <= counter + 1'b1;
				end
				
			CAMERA_INIT_7:
				begin
					reg_address <= 0;
					data_in_bus <= 0;
					bus_write <= 1'b0;
				end
				
			CAMERA_IDLE:
				begin
					reg_address <= 0;
					data_in_bus <= 0;
					bus_write <= 1'b0;
				end
				
			default:
				begin
					bus_write <= 1'b0;
					reg_address <= 3'd0;
					data_in_bus <= 8'd0;
				end
		endcase
	end
end

endmodule
