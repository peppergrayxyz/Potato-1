
`default_nettype none

module xyz_peppergray_Potato1_Main(
  input [7:0] io_in,
  output [7:0] io_out
);

  localparam INSTR_WITH   = 4;
  localparam INSTR_NUM    = 9;
  localparam MODE_WITH    = 3;
  localparam STAT_WITH    = 1;
  localparam CNTRL_WITH   = 9;
  localparam CMD_WITH     = 8;
  localparam LOOPCTR_WITH = 32;

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

  wire Clock   = io_in[0];
  wire Reset_n = io_in[1];

  reg ZeroFlag;
  reg IOWait;
  reg [INSTR_WITH-1:0] Instruction;

  always @(posedge Clock or negedge Reset_n) begin
    if(~Reset_n) begin
      Instruction <= 4'b1111;
      ZeroFlag    <= 0;
      IOWait      <= 0;
    end
    else begin
      Instruction <= io_in[7:4];
      ZeroFlag    <= io_in[3];
      IOWait      <= (IOActivity && io_in[2]);
    end
  end

  /* InstructionDecode */  
  reg [INSTR_NUM-1:0] MicroInstruction;
  
  always @ * begin
    case(Instruction)
      4'b0000: begin MicroInstruction <= (1 << CTRL_X_INC); end
      4'b0001: begin MicroInstruction <= (1 << CTRL_X_DEC); end
      4'b0010: begin MicroInstruction <= (1 << CTRL_A_INC); end
      4'b0011: begin MicroInstruction <= (1 << CTRL_A_DEC); end
      4'b0100: begin MicroInstruction <= (1 << CTRL_PUT);   end
      4'b0101: begin MicroInstruction <= (1 << CTRL_GET);   end
      4'b0110: begin MicroInstruction <= (1 << CTRL_LOOP);  end
      4'b0111: begin MicroInstruction <= (1 << CTRL_DONE);  end
      4'b1111: begin MicroInstruction <= (1 << CTRL_HALT);  end
      default: begin MicroInstruction <= 0; /* CTRL_NOP */  end
    endcase
  end

  /* LoopControl */
  reg Reverse;
  reg SkipCmd;
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
  wire Up    = (reverse ? Done : Loop);
  wire Down  = (reverse ? Loop : Done);
  wire Store = setSkipCmd;
  
  reg [LOOPCTR_WITH-1:0] LoopCounter;
  reg [LOOPCTR_WITH-1:0] LoopJmpMark;
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
        LoopCounter <= LoopCounter + (Count ? (Up ? 1 : Down ? -1 : 0) : 0);
      end
      
      if(Store) begin
        LoopJmpMark <= LoopCounter + (Count ? (Up ? 1 : Down ? -1 : 0) : 0);
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

  /* ExecutionControl */
  reg [CNTRL_WITH-1:0] Control;
  
  always @ * begin
    if(IOWait) begin
      Control <= Control;
    end
    else if(SkipCmd) begin
      Control <= 0;
    end
    else begin
      Control <= MicroInstruction;
    end
  end

  /* ProgramCounter */
  reg [1:0] Control_PC;
    
  assign Control_PC[X_PC_INC] =  !Reverse && !(Control[CTRL_HALT] || IOWait);
  assign Control_PC[X_PC_DEC] =   Reverse && !(Control[CTRL_HALT] || IOWait);

  /* OutputController */
  reg [CMD_WITH-1:0] Command;
  assign io_out = Command;

  wire IOActivity = (Command[CMD_OFFSET + CTRL_GET] || Command[CMD_OFFSET + CTRL_PUT]);

  always @(negedge Clock or negedge Reset_n) begin
    if(~Reset_n) begin
      Command <= 0;
    end
    else begin
      Command <= { Control[5:0], Control_PC[1:0]};
    end
  end

endmodule
