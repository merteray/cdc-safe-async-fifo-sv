`timescale 1ns/1ps

module tb_async_fifo;

  localparam int DATA_WIDTH = 8;
  localparam int DEPTH      = 8;
  localparam int ADDR_WIDTH = $clog2(DEPTH);

  logic                  wr_clk;
  logic                  wr_rst_n;
  logic                  wr_en;
  logic [DATA_WIDTH-1:0] wr_data;
  logic                  full;
  logic                  almost_full;
  logic                  overflow;

  logic                  rd_clk;
  logic                  rd_rst_n;
  logic                  rd_en;
  logic [DATA_WIDTH-1:0] rd_data;
  logic                  empty;
  logic                  almost_empty;
  logic                  underflow;

  async_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) dut (
    .wr_clk(wr_clk),
    .wr_rst_n(wr_rst_n),
    .wr_en(wr_en),
    .wr_data(wr_data),
    .full(full),
    .almost_full(almost_full),
    .overflow(overflow),

    .rd_clk(rd_clk),
    .rd_rst_n(rd_rst_n),
    .rd_en(rd_en),
    .rd_data(rd_data),
    .empty(empty),
    .almost_empty(almost_empty),
    .underflow(underflow)
  );

  // Write clock: 100 MHz equivalent, 10 ns period
  initial wr_clk = 0;
  always #5 wr_clk = ~wr_clk;

  // Read clock: slower, 40 MHz equivalent, 25 ns period
  initial rd_clk = 0;
  always #12.5 rd_clk = ~rd_clk;

  // Waveform dump
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_async_fifo);
  end

  task automatic reset_dut();
    begin
      wr_rst_n = 0;
      rd_rst_n = 0;
      wr_en    = 0;
      rd_en    = 0;
      wr_data  = '0;

      repeat (5) @(posedge wr_clk);
      repeat (5) @(posedge rd_clk);

      wr_rst_n = 1;
      rd_rst_n = 1;

      repeat (5) @(posedge wr_clk);
      repeat (5) @(posedge rd_clk);
    end
  endtask

  task automatic write_fifo(input logic [DATA_WIDTH-1:0] data);
    begin
      @(negedge wr_clk);
      wr_en   = 1'b1;
      wr_data = data;

      @(posedge wr_clk);
      #1;

      @(negedge wr_clk);
      wr_en   = 1'b0;
      wr_data = '0;
    end
  endtask

  task automatic read_fifo(input logic [DATA_WIDTH-1:0] expected);
    logic [DATA_WIDTH-1:0] actual;
    begin
      // Read side may need time to see write pointer through synchronizer.
      wait (empty == 1'b0);

      @(negedge rd_clk);
      rd_en = 1'b1;

      #1;
      actual = rd_data;

      if (actual !== expected) begin
        $error("READ MISMATCH: expected=0x%0h actual=0x%0h time=%0t",
               expected, actual, $time);
      end else begin
        $display("READ PASS: data=0x%0h time=%0t", actual, $time);
      end

      @(posedge rd_clk);
      #1;

      @(negedge rd_clk);
      rd_en = 1'b0;
    end
  endtask

  initial begin
    $display("Starting async FIFO sanity test...");

    reset_dut();

    // ------------------------------------------------------------
    // Test 1: reset state
    // ------------------------------------------------------------
    if (full !== 1'b0) begin
      $error("After reset, full should be 0");
    end

    if (empty !== 1'b1) begin
      $error("After reset, empty should be 1");
    end

    $display("Reset test passed.");

    // ------------------------------------------------------------
    // Test 2: basic write/read order
    // ------------------------------------------------------------
    write_fifo(8'h11);
    write_fifo(8'h22);
    write_fifo(8'h33);

    read_fifo(8'h11);
    read_fifo(8'h22);
    read_fifo(8'h33);

    $display("Basic write/read test completed.");

    // Give some time for empty flag to update
    repeat (5) @(posedge rd_clk);

    if (empty !== 1'b1) begin
      $error("FIFO should be empty after reading all data");
    end else begin
      $display("Empty flag test passed.");
    end

    // ------------------------------------------------------------
    // Test 3: fill FIFO and check full
    // ------------------------------------------------------------
    for (int i = 0; i < DEPTH; i++) begin
      write_fifo(i[DATA_WIDTH-1:0]);
    end

    repeat (2) @(posedge wr_clk);

    if (full !== 1'b1) begin
      $error("FIFO should be full after DEPTH writes");
    end else begin
      $display("Full flag test passed.");
    end

    // ------------------------------------------------------------
    // Test 4: overflow
    // ------------------------------------------------------------
    write_fifo(8'hAA);

    repeat (2) @(posedge wr_clk);

    if (overflow !== 1'b1) begin
      $error("Overflow should be set after writing while full");
    end else begin
      $display("Overflow test passed.");
    end

    // ------------------------------------------------------------
    // Test 5: drain FIFO
    // ------------------------------------------------------------
    for (int i = 0; i < DEPTH; i++) begin
      read_fifo(i[DATA_WIDTH-1:0]);
    end

    repeat (5) @(posedge rd_clk);

    if (empty !== 1'b1) begin
      $error("FIFO should be empty after draining");
    end else begin
      $display("Drain test passed.");
    end

    // ------------------------------------------------------------
    // Test 6: underflow
    // ------------------------------------------------------------
    @(negedge rd_clk);
    rd_en = 1'b1;

    @(posedge rd_clk);
    #1;

    @(negedge rd_clk);
    rd_en = 1'b0;

    repeat (2) @(posedge rd_clk);

    if (underflow !== 1'b1) begin
      $error("Underflow should be set after reading while empty");
    end else begin
      $display("Underflow test passed.");
    end

    $display("All sanity tests completed.");
    $finish;
  end

endmodule