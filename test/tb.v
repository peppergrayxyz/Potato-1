`default_nettype none
`timescale 1ns/1ps

/*
this testbench just instantiates the module and makes some convenient wires
that can be driven / tested by the cocotb test.py
*/

module tb (
    // testbench is controlled by test.py
    input clk,
    input rst_n,
    input iowait,
    input zeroflag,
    input [3:0] instruction,
    output [1:0] pc,
    output [5:0] command
   );

    // this part dumps the trace to a vcd file that can be viewed with GTKWave
    initial begin
        $dumpfile ("tb.vcd");
        $dumpvars (0, tb);
        #1;
    end

    // wire up the inputs and outputs
    wire [7:0] inputs = {instruction, zeroflag, iowait, rst_n, clk};
    wire [7:0] outputs;
    assign pc = outputs[1:0];
    assign command = outputs[7:2];

    // instantiate the DUT
     xyz_peppergray_Potato1_Main main(
        .io_in  (inputs),
        .io_out (outputs)
        );

endmodule
