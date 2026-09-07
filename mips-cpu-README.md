# Pipelined MIPS CPU

A 5-stage pipelined MIPS processor implemented in Verilog, synthesized and deployed to a Xilinx Zynq FPGA.

## Architecture

Classic 5-stage RISC pipeline: **IF → ID → EXE → MEM → WB**, built from a 9-module datapath (instruction memory, data memory, register file, ALU, control unit, and pipeline registers between each stage).

## Features

- **Data hazard forwarding** — EXE/MEM and MEM/WB bypass paths feed results back into the execute stage before they've been written back
- **Hazard detection & stalling** — a dedicated stall unit inserts bubbles for load-use hazards that forwarding alone can't resolve
- **Branch/jump support** — `beq`, `bne`, `j`, `jal`, `jr`, with branch comparison resolved early (in decode) to minimize the pipeline penalty
- **Self-checking testbench** — verifies register file, ALU, and write-back behavior cycle-by-cycle against expected execution

## Implementation

Carried through the full FPGA flow in Xilinx Vivado: synthesis → placement → routing → bitstream generation, targeting a Zynq-7000 (`xc7z010`) board. Post-route timing was reviewed to identify critical paths under real hardware constraints.

## Repo layout

```
/rtl          Verilog source for the datapath modules
/tb           Testbench(es)
/constraints  Vivado XDC constraint files
```

## Tools

Verilog · Xilinx Vivado · Zynq-7000 FPGA
