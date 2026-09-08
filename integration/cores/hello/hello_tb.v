`timescale 1ns/1ps
module hello_tb;
  reg clk = 0;
  reg rst_n = 0;
  wire [3:0] count;
  hello dut (.clk(clk), .rst_n(rst_n), .count(count));
  always #5 clk = ~clk;
  initial begin
    #12 rst_n = 1;
    wait (count == 4'd15);
    @(posedge clk);
    $display("hello: counter wrapped, count=%0d", count);
    $finish;
  end
endmodule
