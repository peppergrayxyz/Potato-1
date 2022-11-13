import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

instructions = {
    ">":     0,
    "<":     1,
    "+":     2,
    "-":     3,
    ".":     4,
    ",":     5,
    "[":     6,
    "]":     7,
    "NOP":   8,
    "NOP2":  9,
    "NOP3": 10,
    "NOP4": 11,
    "NOP5": 12,
    "NOP6": 13,
    "NOP7": 14,
    "HALT": 15
}

command = {
    "INC_PC": 0,
    "DEC_PC": 1,
    "INC_X":  0,
    "DEC_X":  1,
    "INC_A":  2,
    "DEC_A":  3,
    "PUT":    4,
    "GET":    5,
}

async def reset(dut):
    dut._log.info("reset")

    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await FallingEdge(dut.clk)

async def init(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    
    await reset(dut)

def t(instruction, command="x", pc="x", zeroflag="x", ioready="x"):
    test = {
        "instruction": instruction
    }

    if command != "x":
        test["command"] = command
    if pc != "x":
        test["pc"] = pc
    if zeroflag != "x":
        test["zeroflag"] = zeroflag
    if ioready != "x":
        test["ioready"] = ioready

    return test

async def run_sequence(dut, sequence):
    
    for idx, x in enumerate(sequence):
        lastidx = idx - 1;
        try:
            y = sequence[idx-1]
        except IndexError:
            y = {}

        for key in x:
            match key:
                case "instruction":
                    dut.instruction.value = instructions[x[key]]
                case "zeroflag":
                    dut.zeroflag.value = x[key]
                case "ioready":
                    dut.ioready.value = x[key]
        
        await RisingEdge(dut.clk)

        for key in y:
            match key:
                case "pc":
                    if y[key] > 0:
                        assert int(dut.pc.value) == (1 << command["INC_PC"])
                    elif y[key] < 0:
                        assert int(dut.pc.value) == (1 << command["DEC_PC"])
                    else:
                        assert int(dut.pc.value) == 0
                case "command":
                    if y[key] == 0:
                        assert int(dut.command.value) == 0
                    else:
                        assert int(dut.command.value) == (1 << command[y[key]])
    
        await FallingEdge(dut.clk)




@cocotb.test()
async def test_reset(dut):
    await init(dut)

    dut._log.info("check command")
    assert int(dut.command.value) == 0
    await RisingEdge(dut.clk)
    assert int(dut.command.value) == 0
    dut.rst_n.value = 0
    await FallingEdge(dut.clk)
    assert int(dut.command.value) == 0
    await RisingEdge(dut.clk)
    assert int(dut.command.value) == 0


@cocotb.test()
async def test_nop(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("NOP",  0, 1),   
        t("NOP2", 0, 1),   
        t("NOP3", 0, 1),   
        t("NOP4", 0, 1),   
        t("NOP5", 0, 1),   
        t("NOP6", 0, 1),   
        t("NOP7", 0, 1),   
        t("NOP")
    ])


@cocotb.test()
async def test_halt(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("HALT",   0,  0),
        t("-", "DEC_A", 1),     
        t("NOP")
    ])


@cocotb.test()
async def test_inc_x(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t(">", "INC_X", 1),   
        t("NOP")
    ])


@cocotb.test()
async def test_dec_x(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("<", "DEC_X", 1),   
        t("NOP")
    ])

    
@cocotb.test()
async def test_inc_a(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("+", "INC_A", 1),   
        t("NOP")
    ])


@cocotb.test()
async def test_dec_a(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("-", "DEC_A", 1),   
        t("NOP")
    ])


@cocotb.test()
async def test_put_no_wait(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t(".", "PUT", 1, ioready=1), 
        t("+", "INC_A", 1),     
        t("NOP")
    ])


@cocotb.test()
async def test_get_no_wait(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t(",", "GET",   1, ioready=1), 
        t("+", "INC_A", 1),     
        t("NOP")
    ])


@cocotb.test()
async def test_put_wait(dut):
    await init(dut)

    await run_sequence(dut, [
        t(".", "PUT", 1, ioready=0), 
        t("+", "PUT", 0),  
        t("-", "PUT", 0), 
        t(">", "PUT", 0), 
        t("<", "PUT", 0),   
        t("+", "INC_A", 1, ioready=1), 
        t("NOP")
    ])
    

@cocotb.test()
async def test_get_wait(dut):
    await init(dut)

    await run_sequence(dut, [
        t(",", "GET", 1, ioready=0), 
        t("+", "GET", 0),  
        t("-", "GET", 0), 
        t(">", "GET", 0), 
        t("<", "GET", 0),   
        t("+", "INC_A", 1, ioready=1), 
        t("NOP")
    ])

@cocotb.test()
async def test_loop_counter(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("[", 0,       1, zeroflag=0), 
        t("[", 0,       1, zeroflag=0), 
        t("[", 0,       1, zeroflag=0), 
        t("]", 0,       1, zeroflag=1), 
        t("]", 0,      -1, zeroflag=0),
        t("]", 0,      -1, zeroflag=0),
        t("[", 0,      -1, zeroflag=0),
        t("[", 0,       1, zeroflag=0),
        t("]", 0,      -1, zeroflag=0),
        t("NOP")
    ])


@cocotb.test()
async def test_loop_simple_loop(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("[", 0,       1, zeroflag=0), 
        t("+", "INC_A", 1),
        t(">", "INC_X", 1),
        t("]", 0,      -1, zeroflag=0), 
        t("-", 0,      -1), 
        t("[", 0,       1), 
        t("+", "INC_A", 1),    
        t("NOP")
    ])
    

@cocotb.test()
async def test_loop_simple_break(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("[", 0,       1, zeroflag=0), 
        t("+", "INC_A", 1),
        t(">", "INC_X", 1),
        t("]", 0,       1, zeroflag=1), 
        t("-", "DEC_A", 1),    
        t("NOP")
    ])


@cocotb.test()
async def test_loop_simple_skip(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("[", 0,       1, zeroflag=1), 
        t("+", 0,       1),
        t(">", 0,       1),
        t("]", 0,       1, zeroflag=0), 
        t("-", "DEC_A", 1),    
        t("NOP")
    ])


@cocotb.test()
async def test_loop_nested_skip1(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("[", 0,       1, zeroflag=1), 
        t("+", 0,       1),
        t("[", 0,       1),
        t("-", 0,       1),
        t("]", 0,       1),
        t(">", 0,       1),
        t("]", 0,       1, zeroflag=0), 
        t("-", "DEC_A", 1),    
        t("NOP")
    ])

    
@cocotb.test()
async def test_loop_nested_skip2(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("[", 0,       1, zeroflag=1),
        t("[", 0,       1, zeroflag=0),
        t("[", 0,       1, zeroflag=0),
        t("]", 0,       1, zeroflag=0),
        t("]", 0,       1, zeroflag=0),
        t("]", 0,       1, zeroflag=0),
        t("-", "DEC_A", 1),     
        t("NOP")
    ])


@cocotb.test()
async def test_loop_empty_skip(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("[", 0,       1, zeroflag=1), 
        t("]", 0,       1, zeroflag=1), 
        t("-", "DEC_A", 1),    
        t("NOP")
    ])


@cocotb.test()
async def test_loop_empty_endless(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("[", 0,       1, zeroflag=0), 
        t("]", 0,      -1, zeroflag=0), 
        t("[", 0,       1, zeroflag=0), 
        t("]", 0,      -1, zeroflag=0), 
        t("NOP")
    ])


@cocotb.test()
async def test_loop_invlaid1(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("[", 0,       1, zeroflag=0), 
        t("]", 0,       1, zeroflag=1),
        t("-", "DEC_A", 1),     
        t("NOP")
    ])
    

@cocotb.test()
async def test_loop_invlaid2(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("]", 0,      -1, zeroflag=0),
        t("-", 0,      -1),     
        t("NOP")
    ])
    

@cocotb.test()
async def test_loop_invlaid3(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("]", 0,       1, zeroflag=1),
        t("-", "DEC_A", 1),     
        t("NOP")
    ])


@cocotb.test()
async def test_loop_fakejump(dut):
    await init(dut)
    
    await run_sequence(dut, [
        t("-", "DEC_A", 1),     
        t("]", 0,      -1, zeroflag=0),
        t("+", 0,      -1),
        t("]", 0,      -1),
        t("[", 0,      -1),
        t("[", 0,       1),
        t("NOP")
    ])
