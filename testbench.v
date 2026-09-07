`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Penn State
// Engineer: Arik Quam
// 
// Create Date: 4/29/2026
// Design Name: Final Project - Extra Credit Option
// Module Name: testbench
// Project Name: Final Project - Extra Credit Option 
// Target Devices: XC7Z010-CLG400-1
// Description: Testbench for Final Project
// 
// This testbench verifies the IF and ID stages by:
//   1. Generating a clock signal
//   2. Running the simulation for multiple clock cycles
//   3. Observing the signals in the waveform viewer
//
//////////////////////////////////////////////////////////////////////////////////

//==============================================================================
// TESTBENCH MODULE
//==============================================================================
// The testbench instantiates the datapath and provides the clock signal.
// All internal signals are wired inside the datapath module.
//
// To view internal signals in simulation:
//   1. In Vivado, run behavioral simulation
//   2. In the waveform viewer, expand the datapath instance (dut)
//   3. Add the signals you want to observe:
//      - IF stage: pc, nextpc, instOut
//      - IF/ID register: dinstOut
//      - ID stage: op, rs, rt, rd, func, imm
//      - Control signals: wreg, m2reg, wmem, aluc, aluimm, regrt
//      - Register file outputs: qa, qb
//      - Sign extender output: imm32
//      - ID/EXE register outputs: ewreg, em2reg, ewmem, ealuc, ealuimm,
//                                  edestReg, eqa, eqb, eimm32
//
// Expected behavior:
//   Cycle 1: PC=100, fetch lw $2, 0($1)
//   Cycle 2: PC=104, fetch lw $3, 4($1), decode lw $2, 0($1)
//   Cycle 3: PC=108, decode lw $3, 4($1), execute lw $2, 0($1)
//   ...
//==============================================================================

module testbench();
    
    //--------------------------------------------------------------------------
    // Signal Declaration
    //--------------------------------------------------------------------------
    // TODO: Declare a reg for the clock signal
    // Hint: reg clk;
    reg clk;
    wire [31:0] wbData_out;
    
    //--------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    //--------------------------------------------------------------------------
    // TODO: Instantiate the datapath module
    // Hint: The datapath only has clk as input
    Datapath dut (
        .clk (clk),
        .wbData_out(wbData_out)
    );
    
    
    //--------------------------------------------------------------------------
    // Clock Generation
    //--------------------------------------------------------------------------
    // TODO: Initialize the clock to 0
    // Hint: Use an initial block
    //
    initial 
    begin
        clk = 0;
    end
    
    
    // TODO: Generate a clock with 10ns period (5ns high, 5ns low)
    // Hint: Use an always block with #5 delay
    always #5 clk = ~clk;
    
    //  all the signals to monitor throughout
    // utilzies monitor to track
    initial 
    begin
        $display("Time | pc+4 | dinst | rs | rt | rd | qa | qb | fwva | fwvb | ealu | malu | wbData | stall | wreg | wwreg | wdestReg");
        $monitor("%0t | %h | %h | %d | %d | %d | %h | %h | %h | %h | %h | %h | %h | %b | %b | %b | %d",
            $time,
            dut.pc,
            dut.dinstOut,
            dut.rs,                 // source register 1
            dut.rt,                 // source register 2
            dut.rd,                 // destination register
            dut.qa,                 // register file output A
            dut.qb,                 // register file output B
            dut.fwva,               // forwarded value A (actual ALU input)
            dut.fwvb,               // forwarded value B (actual ALU input)
            dut.ern_result,             // ALU output/ealu
            dut.malu,               // MEM stage ALU
            dut.wbData,             // data being written back
            dut.stall,
            dut.wreg,               // write enable in ID
            dut.wwreg,              // write enable in WB
            dut.wdestReg            // which register is being written
        );
        #580; // 58 cycles
        $display("Monitoring Complete");
        $finish;
    end
   

endmodule
