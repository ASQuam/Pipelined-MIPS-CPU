`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University: Penn State
// Engineer: Arik Quam
//
//////////////////////////////////////////////////////////////////////////////////

//==============================================================================
// TOP-LEVEL DATAPATH MODULE
//==============================================================================
// This module connects all the pipeline stages together.
// Input:  clk - clock signal
// Output: None (all signals are internal)
//
//==============================================================================

module Datapath(
    input clk,
    output [31:0] wbData_out
);

    
    // Declare wires for IF stage
    wire [31:0] pc;
    wire [31:0] pc4;
    wire [31:0] nextpc;
    wire [31:0] instOut;
    wire [31:0] dinstOut;
    wire [31:0] dpc4;
    
    // Declare wire for IF/ID pipeline register output
    wire [5:0] op;
    wire [4:0] rs;
    wire [4:0] rt;
    wire [4:0] rd;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] addr; // jump address
    
    // Decode instruction fields from dinstOut
    assign op = dinstOut[31:26];
    assign rs = dinstOut[25:21];
    assign rt = dinstOut[20:16];
    assign rd = dinstOut[15:11];
    assign func = dinstOut[5:0];
    assign imm = dinstOut[15:0];
    assign addr = dinstOut[25:0];
    
    // Declare wires for control unit outputs
    wire wreg; // write register enable (1 bit)
    wire m2reg; // memory to register (1 bit)
    wire wmem; // write memory enable (1 bit)
    wire [3:0] aluc; // ALU control (4 bits)
    wire aluimm; // ALU immediate select (1 bit)
    wire regrt; // select signal (0 = rd, 1 = rt)
    wire [2:0] pcsrc; // pc source select
    wire i_rs; // instruction used rs
    wire i_rt; // instruction uses rt
    wire shift; // shift indiciation
    wire sext; // sign extent vs zero extend
    
    // Declare wires for ID stage
    wire [4:0] destReg; // destination register (5 bits)
    wire [31:0] qa; // register data A (32 bits)
    wire [31:0] qb; // register data B (32 bits)
    wire [31:0] imm32; // sign-extended immediate (32 bits)
    
    // Branch/Jump logic
    wire [31:0] bpc; // branch target addr
    wire [31:0] jpc; // Jump target addr
    wire [31:0] da; // forwarded register values
    wire [31:0] db; // forwarded register values
    wire rsrtequ; // registers equal (branch)
    
    // Pipeline control
    wire stall; // pipeline stall
    wire wpcir; // write enable for PC and IF/ID
    
    // Declare wires for ID/EXE pipeline register outputs
    wire ewreg;   // write register enable
    wire em2reg;  // memory to register
    wire ewmem; // write memory enable
    wire [3:0] ealuc;   // ALU control
    wire ealuimm; // ALU immediate select
    wire [4:0] edestReg; // destination register
    wire [31:0] eqa;     // register data A
    wire [31:0] eqb;    // register data B
    wire [31:0] eimm32;  // sign-extended immediate
    wire [4:0] ers; // Source Register rs carried from EX
    wire [4:0] ert; //  Source Register rt carried from EX
    wire [31:0] epc4; // PC+4 in EXE
    wire ejal; // jal instruction
    wire eshift; // shift
    
    // WIRES FOR EXE STAGE
    wire [31:0] aluOut; // ALU Result
    wire [1:0] fwda; // Control Signal alu input a
    wire [1:0] fwdb; // Control Signal alu input b
    reg [31:0] fwva; // value for alu a
    reg [31:0] fwvb; // value for alu b
    wire [31:0] epc8; // PC+8 for jal return addr
    wire [31:0] ern_result; // result with jal
    wire [4:0] ern_final; // destination register for jal
    
    // wires for EXE/MEM Pipeline
    wire mwreg; // write register enable
    wire mm2reg; // memory to register
    wire mwmem; // write memory enable
    wire [4:0] mdestReg; // destination register
    wire [31:0] malu; // ALU Result
    wire [31:0] mb; // B Register
    
    // wires for MEM stage
    wire [31:0] mdo; // Memory Data Output
    
    // wires for MEM/WB Pipeline
    wire wwreg; // write register enable
    wire wm2reg; // memory to register
    wire [4:0] wdestReg; // destination register
    wire [31:0] walu; // ALU Result
    wire [31:0] wdo; // Memory Data Output
    
    // wires for WB stage
    wire [31:0] wbData; // WB mux output
    
    
    // additional forwarding logic with Alu
    always @(*)
    begin  
        case (fwda)
            2'b00: fwva = eqa;
            2'b10: fwva = malu;
            2'b01: fwva = wbData;
            default:
                fwva = eqa;
        endcase
        
        case (fwdb)
            2'b00: fwvb = eqb;
            2'b10: fwvb = malu;
            2'b01: fwvb = wbData;
            default:
                fwvb = eqb;
        endcase
     end
     
     // jal support
     assign epc8 = epc4 + 4;
     assign ern_result = ejal ? epc8 : aluOut;
     assign ern_final = ejal ? 5'd31 : edestReg;
     
     // shift amount
     wire [4:0] sa;
    assign sa = eimm32[10:6];
    
    // implmentation output
    assign wbData_out = wbData;
    
    
    
    //==========================================================================
    // STAGE 1: INSTRUCTION FETCH (IF) - Instantiate modules
    //==========================================================================
    
    // Instantiate PC (Program Counter)
    PC program_counter (
        .clk (clk),
        .nextpc (nextpc),
        .pc (pc),
        .wpcir(wpcir)
    );
    // Instantiate PCAdd4 (PC + 4 Adder)
    PCAdd4 pc_add (
        .pc (pc),
        .pc4 (pc4) //adjusted name
    );
    // Instantiate IM (Instruction Memory)
    IM instr_mem (
        .a (pc), // changed name to fit project
        .inst (instOut) // changed name to fit project
    );
    
    // Instantiate IFID (IF/ID Pipeline Register)
    IFID pipe_reg (
        .clk (clk),
        .instOut (instOut),
        .pc4 (pc4),
        .dinstOut (dinstOut),
        .dpc4 (dpc4),
        .wpcir(wpcir)
    );

    //==========================================================================
    // STAGE 2: INSTRUCTION DECODE (ID) - Instantiate modules
    //==========================================================================
    
    // Instantiate CU (Control Unit)
    CU control_unit(
        .op (op),
        .func (func),
        .rs (rs),
        .rt (rt),
        .wreg (wreg),
        .m2reg (m2reg),
        .wmem (wmem),
        .aluc (aluc),
        .aluimm (aluimm),
        .regrt (regrt),
        .pcsrc (pcsrc),
        .i_rs(i_rs),
        .i_rt(i_rt),
        .shift(shift),
        .sext(sext) 
    );
    // Instantiate Regfile (Register File)
    Regfile register_file(
        .clk (clk),
        .rs (rs),
        .rt (rt),
        .wdestReg (wdestReg),
        .wbData (wbData),
        .wwreg (wwreg),
        .qa (qa),
        .qb (qb)
    );
    // Instantiate Mux (Regrt Multiplexer)
    Mux regrt_mux(
        .a (rd), // adjusted name
        .b (rt), // adjusted name
        .sel (regrt), // adjusted name
        .out (destReg)  // adjusted name   
    );
    // Instantiate Ext (Sign Extender)
    Ext sign_ext(
        .imm (imm),
        .sext(sext),
        .imm32 (imm32)
    ); 
    // Branch target addr calc
    BranchAddr branch_calc(
        .dpc4 (dpc4),
        .imm32 (imm32),
        .bpc (bpc)
    );
    
    // Jump target addr calc
    JumpAddr jump_calc(
        .dpc4 (dpc4),
        .addr (addr),
        .jpc (jpc)
    );
    
    // branch comparison forwarding
    ForwardID id_forward (
        .qa (qa),
        .qb (qb),
        .edestReg (edestReg),
        .aluOut (aluOut),
        .ewreg (ewreg),
        .em2reg (em2reg),
        .mdestReg (mdestReg),
        .malu (malu),
        .mwreg (mwreg),
        .mm2reg (mm2reg),
        .wdestReg (wdestReg),
        .wbData (wbData),
        .wwreg (wwreg),
        .rs (rs),
        .rt (rt),
        .da (da),
        .db (db)
     );
    
    // Branch check
    assign rsrtequ = (da == db);
    
    // PC source multiplexer
    PCMux pc_mux (
        .pc4 (pc4),
        .bpc (bpc),
        .da (da),
        .jpc (jpc),
        .pcsrc (pcsrc),
        .rsrtequ (rsrtequ),
        .npc (nextpc)
    );
    
    // Stall detection
    StallUnit stall_detector (
        .ewreg (ewreg),
        .em2reg (em2reg),
        .edestReg (edestReg),
        .i_rs (i_rs),
        .i_rt(i_rt),
        .rs (rs),
        .rt (rt),
        .stall (stall)
    );
    
    assign wpcir = ~stall;
    
    // Instantiate IDEXE (ID/EXE Pipeline Register)
    IDEXE pipeline_reg(
        .clk (clk),
        .wreg (wreg),
        .m2reg (m2reg),
        .wmem (wmem),
        .aluc (aluc),
        .aluimm (aluimm),
        .destReg (destReg),
        .qa (qa),
        .qb (qb),
        .imm32 (imm32),
        .rs (rs),
        .rt (rt),
        .pc4 (dpc4),
        .jal (pcsrc == 3'b011 && op == 6'b000011),
        .shift (shift),
        .stall (stall),
        .ewreg (ewreg),
        .em2reg (em2reg),
        .ewmem (ewmem),
        .ealuc (ealuc),
        .ealuimm (ealuimm),
        .edestReg (edestReg),
        .eqa (eqa),
        .eqb (eqb),
        .eimm32 (eimm32),
        .ers (ers),
        .ert (ert),
        .epc4 (epc4),
        .ejal (ejal),
        .eshift (eshift)
    );
    
    //==========================================================================
    // STAGE 3: EXECUTION STAGE - Instantiate modules
    //==========================================================================
    
    
    
    ALU alu_unit(
        .a (fwva),
        .b (fwvb),
        .shift (eshift),
        .aluc (ealuc),
        .aluimm (ealuimm),
        .imm32 (eimm32),
        .aluOut (aluOut),
        .sa(sa)
    );
    
    // exe forwarding logic
    ForwardingUnit exe_forward (
        .ers (ers),
        .ert (ert),
        .mdestReg (mdestReg),
        .wdestReg (wdestReg),
        .mwreg (mwreg),
        .mm2reg (mm2reg),
        .wwreg (wwreg),
        .fwda (fwda),
        .fwdb (fwdb)
    );
    
    EXEMEM pipeline_exemem(
        .clk (clk),
        .ewreg (ewreg),
        .em2reg (em2reg),
        .ewmem (ewmem),
        .edestReg (ern_final),
        .aluOut (ern_result),
        .eqb (fwvb),
        .mwreg (mwreg),
        .mm2reg (mm2reg),
        .mwmem (mwmem),
        .mdestReg (mdestReg),
        .malu (malu),
        .mb (mb)
    );
    
    //==========================================================================
    // STAGE 4: MEMORY STAGE - Instantiate modules
    //==========================================================================
    
    DM data_memory(
        .clk (clk),
        .addr (malu), // name changed to fit project
        .datain (mb), // name changed to fit project
        .we (mwmem), // name changed to fit project
        .dataout (mdo) // name changed to fit project
    );
    
    MEMWB pipeline_memwb(
        .clk (clk),
        .mwreg (mwreg),
        .mm2reg (mm2reg),
        .mdestReg (mdestReg),
        .malu (malu),
        .mdo (mdo),
        .wwreg (wwreg),
        .wm2reg (wm2reg),
        .wdestReg (wdestReg),
        .walu (walu),
        .wdo (wdo)
    );
    
    //==========================================================================
    // STAGE 5: WRITE-BACK STAGE - Instantiate modules
    //==========================================================================
    WBMux wb_mux(
        .walu (walu),
        .wdo (wdo),
        .wm2reg (wm2reg),
        .wbData (wbData)
    );
    
endmodule

//==============================================================================
// STAGE 1: INSTRUCTION FETCH (IF) MODULES
//==============================================================================

//------------------------------------------------------------------------------
// PC - Program Counter
//------------------------------------------------------------------------------


module PC(
    input clk,
    input [31:0] nextpc,
    input wpcir,
    output reg [31:0] pc
);
    // Implement the program counter
    // Initialize pc to 100, update to nextpc on each clock edge
    // pc to 100
    initial
    begin
        pc = 32'h00000000; // address 0
    end
    // updates pc to nextpc
    always @(posedge clk)
    begin
        if(wpcir)
            pc <= nextpc;
        else
            pc <= pc;
    end
    
    
endmodule


//------------------------------------------------------------------------------
// PCAdd4 - PC + 4 Adder
//------------------------------------------------------------------------------


module PCAdd4(
    input [31:0] pc,
    output reg [31:0] pc4
);
    // Implement the PC + 4 adder
    always @(*)
    begin
        pc4 = pc + 4;
    end
    
endmodule


//------------------------------------------------------------------------------
// IM - Instruction Memory
//------------------------------------------------------------------------------


module IM(
    input [31:0] a, // rom address
    output [31:0] inst // rom content = rom[a]
);
    reg [31:0] rom [0:63]; // rom cells: 64 words * 32 bits
    initial
    begin
        // rom[word_addr] = instruction // (pc) label instruction
        rom[6'h00] = 32'h3c010000; // (00) main: lui $1, 0
        rom[6'h01] = 32'h34240050; // (04) ori $4, $1, 80
        rom[6'h02] = 32'h0c00001b; // (08) call: jal sum
        rom[6'h03] = 32'h20050004; // (0c) dslot1: addi $5, $0, 4
        rom[6'h04] = 32'hac820000; // (10) return: sw $2, 0($4)
        rom[6'h05] = 32'h8c890000; //   (14) lw $9, 0($4)
        rom[6'h06] = 32'h01244022; // (18) sub $8, $9, $4
        rom[6'h07] = 32'h20050003; // (1c) addi $5, $0, 3
        rom[6'h08] = 32'h20a5ffff; // (20) loop2: addi $5, $5, -1
        rom[6'h09] = 32'h34a8ffff; // (24) ori $8, $5, 0xffff
        rom[6'h0a] = 32'h39085555; // (28) xori $8, $8, 0x5555
        rom[6'h0b] = 32'h2009ffff; // (2c) addi $9, $0, -1
        rom[6'h0c] = 32'h312affff; // (30) andi $10,$9,0xffff
        rom[6'h0d] = 32'h01493025; // (34) or $6, $10, $9
        rom[6'h0e] = 32'h01494026; // (38) xor $8, $10, $9
        rom[6'h0f] = 32'h01463824; // (3c) and $7, $10, $6
        rom[6'h10] = 32'h10a00003; // (40) beq $5, $0, shift
        rom[6'h11] = 32'h00000000; // (44) dslot2: nop
        rom[6'h12] = 32'h08000008; // (48) j loop2
        rom[6'h13] = 32'h00000000; // (4c) dslot3: nop
        rom[6'h14] = 32'h2005ffff; // (50) shift: addi $5, $0, -1
        rom[6'h15] = 32'h000543c0; // (54) sll $8, $5, 15
        rom[6'h16] = 32'h00084400; // (58) sll $8, $8, 16
        rom[6'h17] = 32'h00084403; // (5c) sra $8, $8, 16
        rom[6'h18] = 32'h000843c2; // (60) srl $8, $8, 15
        rom[6'h19] = 32'h08000019; // (64) finish: j finish
        rom[6'h1a] = 32'h00000000; // (68) dslot4: nop
        rom[6'h1b] = 32'h00004020; // (6c) sum: add $8, $0, $0
        rom[6'h1c] = 32'h8c890000; // (70) loop: lw $9, 0($4)
        rom[6'h1d] = 32'h01094020; // (74) stall: add $8, $8, $9
        rom[6'h1e] = 32'h20a5ffff; // (78) addi $5, $5, -1
        rom[6'h1f] = 32'h14a0fffc; // (7c) bne $5, $0, loop
        rom[6'h20] = 32'h20840004; // (80) dslot5: addi $4, $4, 4
        rom[6'h21] = 32'h03e00008; // (84) jr $31
        rom[6'h22] = 32'h00081000; // (88) dslot6: sll $2, $8, 0
     end
        assign inst = rom[a[7:2]]; // use 6-bit word address to read rom
endmodule


//------------------------------------------------------------------------------
// IFID - IF/ID Pipeline Register
//------------------------------------------------------------------------------


module IFID(
    input clk,
    input [31:0] instOut,
    input [31:0] pc4,
    input wpcir,
    output reg [31:0] dinstOut,
    output reg [31:0] dpc4
);
    // Implement the IF/ID pipeline register
    always @(posedge clk) 
    begin
        if (wpcir) 
        begin
            dinstOut <= instOut;
            dpc4 <= pc4;
        end
    end
endmodule


//==============================================================================
// STAGE 2: INSTRUCTION DECODE (ID) MODULES
//==============================================================================

//------------------------------------------------------------------------------
// CU - Control Unit
//------------------------------------------------------------------------------


module CU(
    input [5:0] op,
    input [5:0] func,
    input [4:0] rs,
    input [4:0] rt,
    output reg wreg,
    output reg m2reg,
    output reg wmem,
    output reg [3:0] aluc,
    output reg aluimm,
    output reg regrt,
    output reg [2:0] pcsrc,
    output reg i_rs,
    output reg i_rt,
    output reg shift,
    output reg sext
);
    // Implement the control unit using a case statement
    always @(*)
    begin
        // Default values
        wreg = 0;
        m2reg = 0;
        wmem = 0;
        aluc = 4'b0010;
        aluimm = 0;
        regrt = 0;
        pcsrc = 3'b000; 
        i_rs = 0;
        i_rt = 0;
        shift = 0;
        sext = 1;
        case(op)
            6'b100011: // lw [ONLY USED CASE IN LAB3]
            begin
                wreg = 1; // reg-write
                m2reg = 1; // memto-reg
                wmem = 0; // write-mem
                aluc = 4'b0010; // alu-add
                aluimm = 1; // alu-immediate
                regrt = 1; // select-signal
                i_rs = 1; // rs source
                i_rt = 0; // rt source
                sext = 1; // sign extend
              end
            // [wanted to build all mentioned instrucitons (Table 2 MIPS integration instruction)]
            6'b101011: // sw 
            begin
                wreg = 0; // reg-write
                m2reg = 0; // memto-reg
                wmem = 1; // write-mem
                aluc = 4'b0010; // alu-add
                aluimm = 1; // alu-immediate
                regrt = 0; // select-signal
                i_rs = 1; // rs source
                i_rt = 1; // rt source
                sext = 1; // sign extend
            end
            6'b000100: // beq
            begin
                wreg = 0; // reg-write
                m2reg = 0; // memto-reg
                wmem = 0; // write-mem
                aluc = 4'b0110; // alu-sub
                aluimm = 0; // alu-immediate
                regrt = 0; // select-signal
                pcsrc = 3'b001; // branch target
                i_rs = 1; // rs source
                i_rt = 1; // rt source
                sext = 1; // sign extend
            end
            6'b000101: // bne
            begin
                wreg = 0; // reg-write
                m2reg = 0; // memto-reg
                wmem = 0; // write-mem
                aluc = 4'b0110; // alu-sub
                aluimm = 0; // alu-immediate
                regrt = 0; // select-signal
                pcsrc = 3'b010; // branch target
                i_rs = 1; // rs source
                i_rt = 1; // rt source
                sext = 1; // sign extend
            end
            6'b001000: // addi
            begin
                wreg = 1; // reg-write
                m2reg = 0; // memto-reg
                wmem = 0; // write-mem
                aluc = 4'b0010; // alu-add
                aluimm = 1; // alu-immediate
                regrt = 1; // select-signal
                i_rs = 1; // rs source
                sext = 1; // sign extend
            end
            6'b001100: // andi
            begin
                wreg = 1; // reg-write
                m2reg = 0; // memto-reg
                wmem = 0; // write-mem
                aluc = 4'b0000; // alu-and
                aluimm = 1; // alu-immediate
                regrt = 1; // select-signal
                i_rs = 1; // rs source
                sext = 0; // sign extend
            end
            6'b001101: // ori
            begin
                wreg = 1; // reg-write
                m2reg = 0; // memto-reg
                wmem = 0; // write-mem
                aluc = 4'b0001; // alu-or
                aluimm = 1; // alu-immediate
                regrt = 1; // select-signal
                i_rs = 1; // rs source
                sext = 0; // sign extend
            end
            6'b001110: // xori
            begin
                wreg = 1; // reg-write
                m2reg = 0; // memto-reg
                wmem = 0; // write-mem
                aluc = 4'b0100; // alu-xor
                aluimm = 1; // alu-immediate
                regrt = 1; // select-signal
                i_rs = 1; // rs source
                sext = 0; // sign extend
            end
            6'b001111: // lui
            begin
                wreg = 1; // reg-write
                m2reg = 0; // memto-reg
                wmem = 0; // write-mem
                aluc = 4'b0011; // shift-left
                aluimm = 1; // alu-immediate
                regrt = 1; // select-signal
                sext = 0; // sign extend
            end
            6'b000010: // j
            begin
                wreg = 0; // reg-write
                m2reg = 0; // memto-reg
                wmem = 0; // write-mem
                aluc = 4'b0000; // alu-and
                aluimm = 0; // alu-immediate
                regrt = 0; // select-signal
                pcsrc = 3'b011;  // jump target
            end
            6'b000011: // jal
            begin
                wreg = 1; // reg-write
                m2reg = 0; // memto-reg
                wmem = 0; // write-mem
                aluc = 4'b0000; // alu-and
                aluimm = 0; // alu-immediate
                regrt = 0; // select-signal
                pcsrc = 3'b011;  // jump target
            end
            6'b000000: // r types
            begin
                wreg = 1; // reg-write
                m2reg = 0; // memto-reg
                wmem = 0; // write-mem
                aluimm = 0; // alu-immediate
                regrt = 0; // select-signal
                i_rs = 1; // rs source
                i_rt = 1; // rt source
                case(func) // specific function
                    6'b100000: aluc = 4'b0010; // add
                    6'b100010: aluc = 4'b0110; // sub
                    6'b100100: aluc = 4'b0000; // and
                    6'b100101: aluc = 4'b0001; // or
                    6'b100110: aluc = 4'b0100; // xor
                    6'b000000: // sll
                    begin
                        aluc = 4'b0011; 
                        shift = 1;
                        i_rs = 0;
                    end
                    6'b000010: // srl
                    begin
                        aluc = 4'b0101; 
                        shift = 1;
                        i_rs = 0;
                    end
                    6'b000011: // sra
                    begin
                        aluc = 4'b1000;
                        shift = 1;
                        i_rs = 0;
                    end
                    6'b101010: aluc = 4'b0111; // slt 
                    6'b001000: // jr, not writing
                    begin
                        wreg = 0;
                        aluc = 4'b0000; // alu-and
                        pcsrc = 3'b100; // use register vals
                        i_rt = 0;
                    end
                    default: aluc = 4'b0000;
                endcase
              end
              default:
              begin
                wreg = 0; // reg-write DEFAULT CASE CHANGED moved to 0
                m2reg = 0; // memto-reg DEFAULT CASE CHANGED moved to 0
                wmem = 0; // write-mem
                aluc = 4'b0010; // alu-add  DEFAULT CASE CHANGED and to add
                aluimm = 0; // alu-immediate DEFAULT CASE CHANGED moved to 0
                regrt = 0; // select-signal
                pcsrc = 3'b000;
                i_rs = 0;
                i_rt = 0;
                shift = 0;
                sext = 1;
              end
        endcase
     end
endmodule


//------------------------------------------------------------------------------
// Regfile - Register File
//------------------------------------------------------------------------------
// Contains 32 general-purpose registers. Provides two read ports.

module Regfile(
    input clk,
    input [4:0] rs,
    input [4:0] rt,
    input [4:0] wdestReg,
    input [31:0] wbData,
    input wwreg,
    output reg [31:0] qa,
    output reg [31:0] qb
);
    // Declare register array
    reg [31:0] registers [0:31];
    // Initialize all 32 registers to 0
    // loops through all registers and sets to 0
    integer i;
    initial
    begin
        for(i = 0; i < 32; i = i + 1)
            registers[i] = 32'b0;
    end
    // Read registers based on rs and rt
    always @(*)
    begin
        qa = registers[rs];
        qb = registers[rt];
    end
    
    // write logic
    always @(posedge clk)
    begin
        if(wwreg && (wdestReg != 0)) // wwreg at 1 then write data to wwreg
            registers[wdestReg] <= wbData;
    end
endmodule


//------------------------------------------------------------------------------
// Mux - Regrt Multiplexer
//------------------------------------------------------------------------------
// Selects the destination register number.
// For R-type instructions, destination is rd.
// For I-type instructions (like lw), destination is rt.
//


module Mux(
    input [4:0] a,
    input [4:0] b,
    input sel,
    output reg [4:0] out
);
    // Implement the multiplexer
    always @(*)
    begin
        if(sel)
            out = b;
        else
            out = a;
    end
    
endmodule


//------------------------------------------------------------------------------
// Ext - Immediate Extender
//------------------------------------------------------------------------------


module Ext(
    input [15:0] imm,
    input sext,
    output reg [31:0] imm32
);
    // Implement sign extension
    always @(*)
    begin
        if (sext)
            imm32 = {{16{imm[15]}}, imm}; // sign extend
        else
            imm32 = {16'b0, imm}; // zero-extend
    end
    
endmodule

// Branch and Jump Calculations

module BranchAddr(
    input [31:0] dpc4,
    input [31:0] imm32,
    output [31:0] bpc
);
    assign bpc = dpc4 + (imm32 << 2);
endmodule
 
module JumpAddr(
    input [31:0] dpc4,
    input [25:0] addr,
    output [31:0] jpc
);
    assign jpc = {dpc4[31:28], addr, 2'b00};
endmodule

// Forward ID stage logic
module ForwardID(
    input [31:0] qa,
    input [31:0] qb,

    // EXE stage forwarding
    input [4:0] edestReg,
    input [31:0] aluOut,
    input ewreg,
    input em2reg,

    // MEM stage forwarding
    input [4:0] mdestReg,
    input [31:0] malu,
    input mwreg,
    input mm2reg,

    // WB stage forwarding
    input [4:0] wdestReg,
    input [31:0] wbData,
    input wwreg,

    input [4:0] rs,
    input [4:0] rt,

    output [31:0] da,
    output [31:0] db
);

    // Forward from EXE stage
    wire fwd_e_rs = ewreg && !em2reg && (edestReg != 0) && (edestReg == rs);
    wire fwd_e_rt = ewreg && !em2reg && (edestReg != 0) && (edestReg == rt);

    // Forward from MEM stage
    wire fwd_m_rs = mwreg && !mm2reg && (mdestReg != 0) && (mdestReg == rs);
    wire fwd_m_rt = mwreg && !mm2reg && (mdestReg != 0) && (mdestReg == rt);

    // Forward from WB stage
    wire fwd_w_rs = wwreg && (wdestReg != 0) && (wdestReg == rs);
    wire fwd_w_rt = wwreg && (wdestReg != 0) && (wdestReg == rt);

    assign da = fwd_e_rs ? aluOut :
                fwd_m_rs ? malu :
                fwd_w_rs ? wbData :
                qa;

    assign db = fwd_e_rt ? aluOut :
                fwd_m_rt ? malu :
                fwd_w_rt ? wbData :
                qb;

endmodule

// promgram counter mux

module PCMux(
    input [31:0] pc4,
    input [31:0] bpc,
    input [31:0] da,
    input [31:0] jpc,
    input [2:0] pcsrc,
    input rsrtequ,
    output reg [31:0] npc
);
    always @(*) begin
        case(pcsrc)
            3'b000: npc = pc4;
            3'b001: npc = rsrtequ ? bpc : pc4; // beq
            3'b010: npc = !rsrtequ ? bpc : pc4; // bne
            3'b011: npc = jpc; // j/jal
            3'b100: npc = da; // jr 
            default: npc = pc4;
        endcase 
    end
endmodule

// stall unit
 
module StallUnit(
    input ewreg,
    input em2reg,
    input [4:0] edestReg,
    input i_rs,
    input i_rt,
    input [4:0] rs,
    input [4:0] rt,
    output stall
);
    assign stall = ewreg && em2reg && (edestReg != 0) && ((i_rs && (edestReg == rs)) || (i_rt && (edestReg == rt)));
endmodule

//------------------------------------------------------------------------------
// IDEXE - ID/EXE Pipeline Register
//------------------------------------------------------------------------------
// Stores all control signals and data from ID stage for use in EXE stage.
// Updates on the positive edge of the clock.

module IDEXE(
    input clk,
    input wreg,
    input m2reg,
    input wmem,
    input [3:0] aluc,
    input aluimm,
    input [4:0] destReg,
    input [31:0] qa,
    input [31:0] qb,
    input [31:0] imm32,
    input [4:0] rs, 
    input [4:0] rt,
    input [31:0] pc4,
    input jal,
    input shift,
    input stall,
    output reg ewreg,
    output reg em2reg,
    output reg ewmem,
    output reg [3:0] ealuc,
    output reg ealuimm,
    output reg [4:0] edestReg,
    output reg [31:0] eqa,
    output reg [31:0] eqb,
    output reg [31:0] eimm32,
    output reg [4:0] ers,
    output reg [4:0] ert,
    output reg  [31:0] epc4,
    output reg  ejal,
    output reg  eshift
);
    //initiail nop
    initial 
    begin
        ewreg = 0;
        em2reg = 0;
        ewmem = 0;
        ealuc = 4'b0000;
        ealuimm = 0;
        edestReg = 5'b0;
        eqa = 32'b0;
        eqb = 32'b0;
        eimm32 = 32'b0;
        ers = 5'b0;
        ert = 5'b0;
        epc4 = 32'b0;
        ejal = 0;
        eshift = 0;
    end
    // Implement the ID/EXE pipeline register
    always @(posedge clk)
    begin
        if (stall)
        begin
            // insert nop
            ewreg <= 0;
            em2reg <= 0;
            ewmem <= 0;
            edestReg <= 0;
            ejal <= 0;
            eshift <= 0;
            ealuc <= 0;
            ealuimm <= 0;
        end
        else
        begin
            ewreg <= wreg;
            em2reg <= m2reg;
            ewmem <= wmem;
            ealuc <= aluc;
            ealuimm <= aluimm;
            edestReg <= destReg;
            eqa <= qa;
            eqb <= qb;
            eimm32 <= imm32;
            ers <= rs;
            ert <= rt;
            epc4 <= pc4;
            ejal <= jal;
            eshift <= shift;
        end
    end
endmodule

//==========================================================================
// STAGE 3: EXECUTION STAGE MODULES
//==========================================================================


// ALU Module
module ALU(
    input [31:0] a,     // register data A
    input [31:0] b,    // register data B
    input [31:0] imm32,  // sign-extended immediate
    input [3:0] aluc,   // ALU control
    input aluimm, // ALU immediate select
    input shift,
    input [4:0] sa, // shift amount
    output reg [31:0] aluOut // Alu output
);
    wire [31:0] operandB;
    assign operandB = aluimm ? imm32 : b; // determine immediate or register
    
    always @(*)
    begin
        case(aluc)
            4'b0000: aluOut = a & operandB; // AND
            4'b0001: aluOut = a | operandB; // OR
            4'b0010: aluOut = a + operandB; // ADD
            4'b0011: aluOut = operandB << sa; // SLL
            4'b0100: aluOut = a ^ operandB; // XOR
            4'b0101: aluOut = operandB >> sa; // SRL
            4'b0110: aluOut = a - operandB; // SUB
            4'b0111: aluOut = ($signed(a) < $signed(operandB)) ? 32'd1 : 32'd0; // SLT compares the values 
            4'b1000: aluOut = $signed(operandB) >>> sa; // SRA shifts right while preserving sign bit
            default: aluOut = 32'b0;
        endcase
    end
endmodule

// exe forwarding
module ForwardingUnit(
    input [4:0] ers,
    input [4:0] ert,
    input [4:0] mdestReg,
    input [4:0] wdestReg,
    input mwreg,
    input mm2reg,
    input wwreg,
    output reg [1:0] fwda,
    output reg [1:0] fwdb
);

    always @(*) begin

        // Forward A
        if (mwreg && !mm2reg &&
            (mdestReg != 0) &&
            (mdestReg == ers))
            
            fwda = 2'b10;  // MEM forwarding

        else if (wwreg &&
                 (wdestReg != 0) &&
                 (wdestReg == ers))
                 
            fwda = 2'b01;  // WB forwarding

        else
            fwda = 2'b00;  // No forwarding


        // Forward B
        if (mwreg && !mm2reg &&
            (mdestReg != 0) &&
            (mdestReg == ert))
            
            fwdb = 2'b10;  // MEM forwarding

        else if (wwreg &&
                 (wdestReg != 0) &&
                 (wdestReg == ert))
                 
            fwdb = 2'b01;  // WB forwarding

        else
            fwdb = 2'b00;  // No forwarding
    end

endmodule


// EXE/MEM Pipeline Register Module
module EXEMEM(
    input clk,
    input ewreg,
    input em2reg,
    input ewmem,
    input [4:0] edestReg,
    input [31:0] aluOut,
    input [31:0] eqb,
    output reg mwreg,
    output reg mm2reg,
    output reg mwmem,
    output reg [4:0] mdestReg,
    output reg [31:0] malu,
    output reg [31:0] mb
);
    // Implement the EXE/MEM pipeline register
    always @(posedge clk)
    begin
        mwreg <= ewreg;
        mm2reg <= em2reg;
        mwmem <= ewmem;
        mdestReg <= edestReg;
        malu <= aluOut;
        mb <= eqb;
    end
endmodule

//==========================================================================
// STAGE 4: MEEMORY STAGE MODULES
//==========================================================================

// DATA MEMORY INTITIALIZATION Module

module DM(
    input clk, // clock
    input [31:0] addr, // ram address
    input [31:0] datain, // data in (to memory)
    input we, // write enable
    output [31:0] dataout // data out (from memory)
);
    reg [31:0] ram [0:31]; // ram cells: 32 words * 32 bits
    assign dataout = ram[addr[6:2]]; // use 5-bit word address
    always @ (posedge clk) 
    begin
        if (we) ram[addr[6:2]] = datain; // write ram
    end
    integer i;
    initial begin // ram initialization
        for (i = 0; i < 32; i = i + 1)
            ram[i] = 0;
        // initaliztion 
        //ram[5'h00] = 32'hA00000AA; 
        //ram[5'h01] = 32'h10000011;
        //ram[5'h02] = 32'h20000022;  
        //ram[5'h03] = 32'h30000033;  
        //ram[5'h04] = 32'h40000044; 
        //ram[5'h05] = 32'h50000055; 
        //ram[5'h06] = 32'h60000066;
        //ram[5'h07] = 32'h70000077; 
        //ram[5'h08] = 32'h80000088;  
        //ram[5'h09] = 32'h90000099;  
        // ram[word_addr] = data // (byte_addr) item in data array
        ram[5'h14] = 32'h000000a3; // (50) data[0] 0 + a3 = a3
        ram[5'h15] = 32'h00000027; // (54) data[1] a3 + 27 = ca
        ram[5'h16] = 32'h00000079; // (58) data[2] ca + 79 = 143
        ram[5'h17] = 32'h00000115; // (5c) data[3] 143 + 115 = 258
        // ram[5'h18] should be 0x00000258, the sum stored by sw instruction
    end
    
endmodule

// MEM/WB Pipeline Register Module
module MEMWB(
    input clk,
    input mwreg,
    input mm2reg,
    input [4:0] mdestReg,
    input [31:0] malu,
    input [31:0] mdo,
    output reg wwreg,
    output reg wm2reg,
    output reg [4:0] wdestReg,
    output reg [31:0] walu,
    output reg [31:0] wdo
);
    // Implement the MEM/WB pipeline register
    always @(posedge clk)
    begin
        wwreg <= mwreg;
        wm2reg <= mm2reg;
        wdestReg <= mdestReg;
        walu <= malu;
        wdo <= mdo;
    end
endmodule

//==========================================================================
// STAGE 5: Write-Back Stage MODULES
//==========================================================================

module WBMux(
    input [31:0] walu,
    input [31:0] wdo,
    input wm2reg,
    output reg [31:0] wbData
);
    always @(*)
    begin
        if(wm2reg)
            wbData = wdo; // for load instructions
        else
            wbData = walu; // r-type instructions
    end
endmodule
