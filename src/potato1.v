
`default_nettype none

localparam CPU_INSTR_WITH   = 4;
localparam CPU_INSTR_NUM    = 9;
localparam CPU_MODE_WITH    = 3;
localparam CPU_STAT_WITH    = 1;
localparam CPU_CNTRL_WITH   = 9;
localparam CPU_CMD_WITH     = 8;
localparam CPU_LOOPCTR_WITH = 32;

localparam CTRL_X_INC  = 0;
localparam CTRL_X_DEC  = 1;
localparam CTRL_A_INC  = 2;
localparam CTRL_A_DEC  = 3;
localparam CTRL_PUT    = 4;
localparam CTRL_GET    = 5;
localparam CTRL_LOOP   = 6;
localparam CTRL_DONE   = 7;
localparam CTRL_HALT   = 8;

localparam X_PC_INC  = 0;
localparam X_PC_DEC  = 1;

localparam CMD_OFFSET = 2;

localparam MODE_REVERSE = 0;
localparam MODE_SKIPCMD = 1;
localparam MODE_WAIT_IO = 2;

localparam STAT_ZERO = 0;

module InstructionDecode
 #(parameter INSTR_WITH = CPU_INSTR_WITH,
   parameter INSTR_NUM = CPU_INSTR_NUM)(
  input Reset_n,
  input Clock,
  input [INSTR_WITH-1:0] Instruction,
  output [CPU_INSTR_NUM-1:0] MicroInstruction
 );
  
  reg [INSTR_WITH-1:0] instruction;
  reg [CPU_INSTR_NUM-1:0] microInstruction;

  assign MicroInstruction = microInstruction;

  always @(posedge Clock or negedge Reset_n) begin
    if(~Reset_n) begin
      instruction <= 4'b1111;
    end
    else begin
      instruction <= Instruction;
    end
  end

  always @ * begin
    case(instruction)
      4'b0000: begin microInstruction <= (1 << CTRL_X_INC); end
      4'b0001: begin microInstruction <= (1 << CTRL_X_DEC); end
      4'b0010: begin microInstruction <= (1 << CTRL_A_INC); end
      4'b0011: begin microInstruction <= (1 << CTRL_A_DEC); end
      4'b0100: begin microInstruction <= (1 << CTRL_PUT);   end
      4'b0101: begin microInstruction <= (1 << CTRL_GET);   end
      4'b0110: begin microInstruction <= (1 << CTRL_LOOP);  end
      4'b0111: begin microInstruction <= (1 << CTRL_DONE);  end
      4'b1111: begin microInstruction <= (1 << CTRL_HALT);  end
      default: begin microInstruction <= 0; /* CTRL_NOP */  end
    endcase
  end

endmodule

module StateRegister
 #(parameter STAT_WITH = CPU_STAT_WITH)(
  input Reset_n,
  input Clock,
  input [STAT_WITH-1:0] State,
  output ZeroFlag
);

  reg [STAT_WITH-1:0] state;

  assign ZeroFlag = state[STAT_ZERO];

  always @(posedge Clock or negedge Reset_n) begin
    if(~Reset_n) begin
      state <= 0;
    end
    else begin
      state <= State;
    end
  end

endmodule

module ExecutionMode
 #(parameter MODE_WITH = CPU_MODE_WITH)(
  input Reset_n,
  input Set_Reverse,
  input Clr_Reverse,
  input Set_SkipCmd,
  input Clr_SkipCmd,
  input Set_WaitIO,
  input Clr_WaitIO,
  output Reverse,
  output SkipCmd,
  output WaitIO
);


  wire [MODE_WITH-1:0] Set;
  wire [MODE_WITH-1:0] Clr;
  reg [MODE_WITH-1:0] Val;
  wire [MODE_WITH-1:0] trigger;

  assign Set[MODE_REVERSE] = Set_Reverse;
  assign Clr[MODE_REVERSE] = Clr_Reverse;
  assign Reverse = Val[MODE_REVERSE];
  
  assign Set[MODE_SKIPCMD] = Set_SkipCmd;
  assign Clr[MODE_SKIPCMD] = Clr_SkipCmd;
  assign SkipCmd = Val[MODE_SKIPCMD];
  
  assign Set[MODE_WAIT_IO] = Set_WaitIO;
  assign Clr[MODE_WAIT_IO] = Clr_WaitIO;
  assign WaitIO = Val[MODE_WAIT_IO];
  
  genvar i;

  generate
    for(i = 0; i < MODE_WITH; i = i+1)
    begin: Gen_StatusRegisters

      assign trigger[i] = Set[i] || Clr[i];

      always @(posedge trigger[i] or negedge Reset_n) begin
        if(~Reset_n) begin
          Val[i] <= 0;
        end
        else if(Set[i]) begin
          Val[i] <= 1;
        end
        else begin
          Val[i] <= 0;
        end
      end
    end
  endgenerate

endmodule

module LoopControl
#(parameter MODE_WITH = CPU_MODE_WITH,
  parameter STAT_WITH = CPU_STAT_WITH,
  parameter INSTR_NUM = CPU_INSTR_NUM)(
  input Reset_n,
  input Clock,
  input ZeroFlag,
  input [INSTR_NUM-1:0] MicroInstruction,
  output Reverse,
  output SkipCmd
);

  reg reverse;
  reg skipCmd;  
  assign Reverse = setReverse ? 1 : clrReverse ? 0 : reverse;
  assign SkipCmd = setSkipCmd ? 1 : clrSkipCmd ? 0 : skipCmd;

  wire Loop = MicroInstruction[CTRL_LOOP];
  wire Done = MicroInstruction[CTRL_DONE];

  wire setSkipCmd_L =!reverse && !skipCmd & ZeroFlag;
  wire clrReverse_L = reverse && markMatch;
  wire clrSkipCmd_L = skipCmd && clrReverse;

  wire setReverse_D = !reverse && !skipCmd && !ZeroFlag;
  wire setSkipCmd_D = setReverse;
  wire clrSkipCmd_D = skipCmd && markMatch;

  wire setSkipCmd = Loop ? setSkipCmd_L : Done ? setSkipCmd_D : 0;
  wire clrSkipCmd = Loop ? clrSkipCmd_L : Done ? clrSkipCmd_D : 0;
  wire setReverse = Done ? setReverse_D : 0;
  wire clrReverse = Loop ? clrReverse_L : 0;

  wire Count = !((!reverse && setReverse) || (reverse && clrReverse));
  wire Up    = (Reverse ? Done : Loop);
  wire Down  = (Reverse ? Loop : Done);
  wire Store = setSkipCmd;
  
  reg [CPU_LOOPCTR_WITH-1:0] LoopCounter;
  reg [CPU_LOOPCTR_WITH-1:0] LoopJmpMark;
  reg [CPU_LOOPCTR_WITH-1:0] nextCounter;

  assign nextCounter = LoopCounter + (Count ? (Up ? 1 : Down ? -1 : 0) : 0);
  wire markMatch     = (LoopJmpMark == LoopCounter);

  always @(negedge Clock or negedge Reset_n) begin
    if(~Reset_n) begin
      LoopCounter <= 0;
      LoopJmpMark <= 0;
      reverse     <= 0;
      skipCmd     <= 0;
    end
    else begin

      if(Count) begin    
        LoopCounter <= nextCounter;
      end
      
      if(Store) begin
        LoopJmpMark <= nextCounter;
      end

      if(clrReverse) begin
        reverse <= 0;
      end
      else if(setReverse) begin
        reverse <= 1;
      end

      if(clrSkipCmd) begin
        skipCmd <= 0;
      end
      else if(setSkipCmd) begin
        skipCmd     <= 1;
      end

    end
  end

endmodule

module ExecutionControl
#(parameter INSTR_NUM = CPU_INSTR_NUM,
  parameter CNTRL_WITH = CPU_CNTRL_WITH)(
  input Reset_n,
  input [CPU_INSTR_NUM-1:0] MicroInstruction,
  input SkipCmd,
  input IOReady,
  input IOActivity,
  output [CNTRL_WITH-1:0] Control,
  output WaitIO 
);
  reg waitIO;
  assign WaitIO  = waitIO && !IOReady; 

  always @ * begin
    if(~Reset_n) begin
      waitIO <= 0;
    end
    else begin
      if(IOActivity || (waitIO & !IOReady)) begin
        waitIO <= 1;
      end
      else begin
        waitIO <= 0;
      end
    end
  end

  reg [CNTRL_WITH-1:0] control;
  assign Control = control;
  
  always @ * begin
    if(~Reset_n) begin
      control <= 0;
    end
    else begin
      if(WaitIO) begin
        control <= control;
      end
      else if(SkipCmd) begin
        control <= 0;
      end
      else begin
        control <= MicroInstruction;
      end
    end
  end

endmodule

module ProgramCounter(
  input ReverseDirection,
  input Halt,
  input Mode_WaitIO,
  output [1:0] Control_PC
);

  assign Control_PC[X_PC_INC] =  !ReverseDirection && !(Halt || Mode_WaitIO);
  assign Control_PC[X_PC_DEC] =   ReverseDirection && !(Halt || Mode_WaitIO);

endmodule

module OutputController
#(parameter CNTRL_WITH = CPU_CNTRL_WITH,
  parameter CMD_WITH   = CPU_CMD_WITH)(
  input Reset_n,
  input Clock,
  input [1:0] ProgramCounter,
  input [CNTRL_WITH-1:0] Control,
  output [CMD_WITH-1:0] Command,
  output IOActivity
);

  reg [CMD_WITH-1:0] command;
  assign Command = command;
  assign IOActivity = (command[CMD_OFFSET + CTRL_GET] || command[CMD_OFFSET + CTRL_PUT]);

  always @(negedge Clock or negedge Reset_n) begin
    if(~Reset_n) begin
      command <= 0;
    end
    else begin
      command <= { Control[5:0], ProgramCounter[1:0]};
    end
  end

endmodule

module ControlUnit
#(parameter INSTR_WITH = CPU_INSTR_WITH,
  parameter INSTR_NUM  = CPU_INSTR_NUM,
  parameter MODE_WITH  = CPU_MODE_WITH,
  parameter STAT_WITH  = CPU_STAT_WITH,
  parameter CNTRL_WITH = CPU_CNTRL_WITH,
  parameter CMD_WITH   = CPU_CMD_WITH)(
  input Clock,
  input Reset_n,
  input IOReady,
  input [STAT_WITH-1:0] State,
  input [INSTR_WITH-1:0] Instruction,
  output [CMD_WITH-1:0] Command
  );

  wire [CPU_INSTR_NUM-1:0] MicroInstruction;
  wire [CNTRL_WITH-1:0] Control;
  wire [1:0]            Control_PC;

  wire ZeroFlag;

  wire Set_Reverse;
  wire Clr_Reverse;
  wire Set_SkipCmd;
  wire Clr_SkipCmd;
  wire Set_WaitIO;
  wire Clr_WaitIO;
  wire Reverse;
  wire SkipCmd;
  wire WaitIO;

  wire IOActivity;

  InstructionDecode 
    #(INSTR_WITH, CNTRL_WITH) 
    Decode(Reset_n, Clock, Instruction, 
    MicroInstruction);

  StateRegister
    #(STAT_WITH)
    StateReg(Reset_n, Clock, State,
    ZeroFlag);

  LoopControl
    #(MODE_WITH, STAT_WITH, INSTR_NUM) 
    Loop(Reset_n, Clock, ZeroFlag, MicroInstruction, 
    Reverse, SkipCmd
    );

  ExecutionControl
    #(INSTR_NUM, CNTRL_WITH)
    Exec(Reset_n, MicroInstruction, SkipCmd, IOReady, IOActivity,
        Control, WaitIO);

  ProgramCounter
    PC(Reverse, Control[CTRL_HALT], WaitIO, 
    Control_PC);

  OutputController
    #(CNTRL_WITH, CMD_WITH) 
    Out(Reset_n, Clock, Control_PC, Control, 
    Command, IOActivity);

endmodule

module xyz_peppergray_Potato1_Main(
  input [7:0] io_in,
  output [7:0] io_out
);

ControlUnit CU0(io_in[0],io_in[1],io_in[2],io_in[3],io_in[7:4],io_out);

endmodule
