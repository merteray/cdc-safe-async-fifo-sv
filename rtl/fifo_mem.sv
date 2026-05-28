`timescale 1ns/1ps

module fifo_mem #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH = 16,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
) (
    input logic wr_clk,
    input logic wr_en,
    input logic [ADDR_WIDTH-1:0] wr_addr,
    input logic [DATA_WIDTH-1:0] wr_data,

    input logic [ADDR_WIDTH -1:0] rd_addr,
    output logic [DATA_WIDTH-1:0] rd_data
);
    
logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

always_ff @(posedge wr_clk) begin
if(wr_en) begin
   mem[wr_addr] <= wr_data; 
end
end

  // Asynchronous read model.
  // For FPGA block RAM inference, this may need to become synchronous
  // depending on target technology and synthesis tool.
  assign rd_data = mem[rd_addr];


endmodule
