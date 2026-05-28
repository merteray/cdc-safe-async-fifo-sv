`timescale 1ns/1ps
module sync_2ff #(
    parameter int WIDHT = 1
) (
    input logic     clk,
    input logic     rst_n,
    input logic  [WIDHT-1:0] async_in,
    output logic  [WIDHT-1:0] sync_out

);

logic [WIDHT-1:0] sync_ff1;

always_ff @( posedge clk or negedge rst_n ) begin 
if(!rst_n) begin
    sync_ff1 <= '0;
    sync_out <= '0;
end else begin
    sync_ff1 <= async_in;
    sync_out <= sync_ff1;
end 
end
    
endmodule
