`timescale 1ns/1ps

module async_fifo_assertions #(
  parameter int PTR_WIDTH = 4
)(
  // Write 
  input logic                 wr_clk,
  input logic                 wr_rst_n,
  input logic                 wr_en,
  input logic                 full,
  input logic                 wr_accept,
  input logic [PTR_WIDTH-1:0] wr_bin,
  input logic [PTR_WIDTH-1:0] wr_gray,

  // Read 
  input logic                 rd_clk,
  input logic                 rd_rst_n,
  input logic                 rd_en,
  input logic                 empty,
  input logic                 rd_accept,
  input logic [PTR_WIDTH-1:0] rd_bin,
  input logic [PTR_WIDTH-1:0] rd_gray
);

  // Helper function: count number of 1s in a vector

  function automatic int count_ones(input logic [PTR_WIDTH-1:0] value);
    int count;
    begin
      count = 0;
      for (int i = 0; i < PTR_WIDTH; i++) begin
        count += value[i];
      end
      return count;
    end
  endfunction


  // Write-domain sampled values

  logic                 wr_past_valid;
  logic                 wr_en_prev;
  logic                 full_prev;
  logic                 wr_accept_prev;
  logic [PTR_WIDTH-1:0] wr_bin_prev;
  logic [PTR_WIDTH-1:0] wr_gray_prev;

  
  // Read-domain sampled values

  logic                 rd_past_valid;
  logic                 rd_en_prev;
  logic                 empty_prev;
  logic                 rd_accept_prev;
  logic [PTR_WIDTH-1:0] rd_bin_prev;
  logic [PTR_WIDTH-1:0] rd_gray_prev;


  // Write-domain assertions


  always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wr_past_valid  <= 1'b0;
      wr_en_prev     <= 1'b0;
      full_prev      <= 1'b0;
      wr_accept_prev <= 1'b0;
      wr_bin_prev    <= '0;
      wr_gray_prev   <= '0;
    end else begin
      if (wr_past_valid) begin

        // Gray pointer should change by at most one bit per write-clock cycle.
        assert (count_ones(wr_gray ^ wr_gray_prev) <= 1)
          else $error("ASSERTION FAILED: wr_gray changed by more than one bit at time %0t", $time);

        // If write was attempted while full, write pointer must not advance.
        if (wr_en_prev && full_prev) begin
          assert (wr_bin == wr_bin_prev)
            else $error("ASSERTION FAILED: wr_bin advanced while FIFO was full at time %0t", $time);
        end

        // If a write was accepted, write pointer should increment by exactly one.
        if (wr_accept_prev) begin
          assert (wr_bin == wr_bin_prev + {{(PTR_WIDTH-1){1'b0}}, 1'b1})
            else $error("ASSERTION FAILED: wr_bin did not increment after accepted write at time %0t", $time);
        end

        // If no write was accepted, write pointer should stay stable.
        if (!wr_accept_prev) begin
          assert (wr_bin == wr_bin_prev)
            else $error("ASSERTION FAILED: wr_bin changed without accepted write at time %0t", $time);
        end
      end

      wr_past_valid  <= 1'b1;
      wr_en_prev     <= wr_en;
      full_prev      <= full;
      wr_accept_prev <= wr_accept;
      wr_bin_prev    <= wr_bin;
      wr_gray_prev   <= wr_gray;
    end
  end


  // Read-domain assertions

  always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rd_past_valid  <= 1'b0;
      rd_en_prev     <= 1'b0;
      empty_prev     <= 1'b0;
      rd_accept_prev <= 1'b0;
      rd_bin_prev    <= '0;
      rd_gray_prev   <= '0;
    end else begin
      if (rd_past_valid) begin

        // Gray pointer should change by at most one bit per read-clock cycle.
        assert (count_ones(rd_gray ^ rd_gray_prev) <= 1)
          else $error("ASSERTION FAILED: rd_gray changed by more than one bit at time %0t", $time);

        // If read was attempted while empty, read pointer must not advance.
        if (rd_en_prev && empty_prev) begin
          assert (rd_bin == rd_bin_prev)
            else $error("ASSERTION FAILED: rd_bin advanced while FIFO was empty at time %0t", $time);
        end

        // If a read was accepted, read pointer should increment by exactly one.
        if (rd_accept_prev) begin
          assert (rd_bin == rd_bin_prev + {{(PTR_WIDTH-1){1'b0}}, 1'b1})
            else $error("ASSERTION FAILED: rd_bin did not increment after accepted read at time %0t", $time);
        end

        // If no read was accepted, read pointer should stay stable.
        if (!rd_accept_prev) begin
          assert (rd_bin == rd_bin_prev)
            else $error("ASSERTION FAILED: rd_bin changed without accepted read at time %0t", $time);
        end
      end

      rd_past_valid  <= 1'b1;
      rd_en_prev     <= rd_en;
      empty_prev     <= empty;
      rd_accept_prev <= rd_accept;
      rd_bin_prev    <= rd_bin;
      rd_gray_prev   <= rd_gray;
    end
  end

endmodule
