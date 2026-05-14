# FPGA UDP Video Streaming — OV2640 Camera to PC (August 2022)
Pure-HDL implementation of a real-time video streaming system on FPGA.
Captures OV2640 camera frames, encapsulates them as UDP/IP/Ethernet packets, 
and broadcasts over 100BASE-T at near-real-time latency.

## Architecture
Camera (OV2640) → SCCB Init → AXI-Stream Capture 
→ RSP Packetizer → UDP/IP Stack → Ethernet MAC (MII) → PHY → PC

## Demo
[UDP video streaming — live camera feed with Wireshark](リンク)

## Key Features
- Custom UDP/IP/Ethernet stack (verilog-ethernet)
- OV2640 camera initialization via SCCB/I2C
- Custom RSP packetizer for frame segmentation
- PC receiver with OpenGL rendering
- Built on Anlogic EG4S20 (Tang Primer)

## Dependencies
- OpenGL, freeglut, boost (PC receiver)
