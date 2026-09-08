`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University: Penn State
// Engineer: Arik Quam
//////////////////////////////////////////////////////////////////////////////////

//==============================================================================
// TESTBENCH MODULE
//==============================================================================
// The testbench instantiates the datapath and provides the clock signal.
// All internal signals are wired inside the datapath module.
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
    // Declare a reg for the clock signal
    reg clk;
    wire [31:0] wbData_out;
    
    //--------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    //--------------------------------------------------------------------------
    // Instantiate the datapath module
    
    Datapath dut (
        .clk (clk),
        .wbData_out(wbData_out)
    );
    
    
    //--------------------------------------------------------------------------
    // Clock Generation
    //--------------------------------------------------------------------------
    // Initialize the clock to 0
    
    initial 
    begin
        clk = 0;
    end
    
    
    // Generate a clock with 10ns period (5ns high, 5ns low)
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
