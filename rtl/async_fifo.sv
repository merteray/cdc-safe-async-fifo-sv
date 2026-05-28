module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH = 16,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
) (
    //write 
    input logic wr_clk,
    input logic wr_rst_n,
    input logic wr_en,
    input logic [DATA_WIDTH-1:0] wr_data,
    output logic full,
    output logic almost_full,
    output logic overflow,

    //read

    input logic rd_clk,
    input logic rd_rst_n,
    input logic rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic empty,
    output logic almost_empty,
    output logic underflow

);
    

    // Parameter check

    initial begin
        if (DEPTH < 2) begin
            $error("DEPTH must be at least 2");
        end
        if ((DEPTH & (DEPTH-1)) != 0) begin
            $error("DEPTH must be power of two for this FIFO implementation");
        end
    end


    //pointer declarations
    //pointers need one extra bit beyond address width.
    //Example: 
    // DEPTH = 16 -> ADDR_WIDTH = 4
    // pointer width = 5 bits
    // the extra bit helps distinguish full from empty after wrap_around.

    logic [ADDR_WIDTH:0] wr_bin,  wr_bin_next;
    logic [ADDR_WIDTH:0] rd_bin,  rd_bin_next;

    logic [ADDR_WIDTH:0] wr_gray, wr_gray_next;
    logic [ADDR_WIDTH:0] rd_gray, rd_gray_next;

    // Synchronized Gray pointers crossing domains
    logic [ADDR_WIDTH:0] rd_gray_sync_wr;
    logic [ADDR_WIDTH:0] wr_gray_sync_rd;

    // Local binary versions of synchronized remote pointers
    logic [ADDR_WIDTH:0] rd_bin_sync_wr;
    logic [ADDR_WIDTH:0] wr_bin_sync_rd;

  // Binary <-> Gray helper functions
    function automatic logic [ADDR_WIDTH:0] bin2gray(
        input logic [ADDR_WIDTH:0] bin
    );
        return (bin>>1) ^ bin;
    endfunction
    
    function automatic logic [ADDR_WIDTH:0] gray2bin(
    input logic [ADDR_WIDTH:0] gray
  );
    logic [ADDR_WIDTH:0] bin;
    bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
    for (int i = ADDR_WIDTH-1; i >= 0; i--) begin
      bin[i] = bin[i+1] ^ gray[i];
    end
    return bin;
  endfunction


sync_2ff #(.WIDHT(ADDR_WIDTH+1)
) u_sync_rdptr_to_wrclk (
    .clk(wr_clk),
    .rst_n(wr_rst_n),
    .async_in(rd_gray),
    .sync_out(rd_gray_sync_wr)
);

  sync_2ff #(
    .WIDHT(ADDR_WIDTH+1)
  ) u_sync_wrptr_to_rdclk (
    .clk      (rd_clk),
    .rst_n    (rd_rst_n),
    .async_in (wr_gray),
    .sync_out (wr_gray_sync_rd)
  );

  assign rd_bin_sync_wr = gray2bin(rd_gray_sync_wr);
  assign wr_bin_sync_rd = gray2bin(wr_gray_sync_rd);


// ------------------------------------------------------------
// Local thresholds
// ------------------------------------------------------------
localparam logic [ADDR_WIDTH:0] FIFO_DEPTH_VALUE =
  (ADDR_WIDTH+1)'(DEPTH);

localparam logic [ADDR_WIDTH:0] ALMOST_FULL_THRESHOLD =
  FIFO_DEPTH_VALUE - (ADDR_WIDTH+1)'(2);

localparam logic [ADDR_WIDTH:0] ALMOST_EMPTY_THRESHOLD =
  (ADDR_WIDTH+1)'(2);

  //Write
  logic wr_accept;
  logic full_next;
  logic [ADDR_WIDTH:0] wr_used_slots; 

  assign wr_accept   = wr_en && !full;
  assign wr_bin_next = wr_bin + {{ADDR_WIDTH{1'b0}}, wr_accept}; 
  assign wr_gray_next = bin2gray(wr_bin_next);
  // Full detection:
  // FIFO is full when the next write pointer equals the synchronized
  // read pointer with the top two bits inverted.
  assign full_next =
    (wr_gray_next == {~rd_gray_sync_wr[ADDR_WIDTH:ADDR_WIDTH-1],
                       rd_gray_sync_wr[ADDR_WIDTH-2:0]});

  // Occupancy estimate in write clock domain.
  // This is based on synchronized read pointer, so it can be delayed.
  assign wr_used_slots = wr_bin - rd_bin_sync_wr;

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if(!wr_rst_n) begin
        wr_bin <= '0;
        wr_gray <= '0;
        full <= 1'b0;
        overflow <= 1'b0;
        almost_full <= 1'b0;

    end else begin
        wr_bin <= wr_bin_next;
        wr_gray <= wr_gray_next;
        full <= full_next;

        if (wr_en && full) begin
            overflow <= 1'b1;
        end
        // Almost full threshold: DEPTH-2 or more entries used.
        // This is a conservative estimate due to pointer synchronization delay.
        almost_full <= (wr_used_slots >= ALMOST_FULL_THRESHOLD);
    end
end


//read
  logic rd_accept;
  logic empty_next;
  logic [ADDR_WIDTH:0] rd_available_slots;
  assign rd_accept    = rd_en && !empty;
  assign rd_bin_next  = rd_bin + {{ADDR_WIDTH{1'b0}}, rd_accept};
  assign rd_gray_next = bin2gray(rd_bin_next);

  // Empty detection:
  // FIFO is empty when the next read pointer equals the synchronized
  // write pointer.
  assign empty_next = (rd_gray_next == wr_gray_sync_rd);
  // Occupancy estimate in read clock domain.
  // This is based on synchronized write pointer, so it can be delayed.
  assign rd_available_slots = wr_bin_sync_rd - rd_bin;

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rd_bin       <= '0;
      rd_gray      <= '0;
      empty        <= 1'b1;
      underflow    <= 1'b0;
      almost_empty <= 1'b1;
    end else begin
        rd_bin  <= rd_bin_next;
      rd_gray <= rd_gray_next;
      empty   <= empty_next;

      if (rd_en && empty) begin
        underflow <= 1'b1;
      end

      // Almost empty threshold: 2 or fewer entries available.
      // This is a conservative estimate due to pointer synchronization delay.
      almost_empty <= (rd_available_slots <= ALMOST_EMPTY_THRESHOLD);
    end
  end


  //MEMORY

  fifo_mem #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH     (DEPTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) u_fifo_mem (
    .wr_clk (wr_clk),
    .wr_en  (wr_accept),
    .wr_addr(wr_bin[ADDR_WIDTH-1:0]),
    .wr_data(wr_data),
    .rd_addr(rd_bin[ADDR_WIDTH-1:0]),
    .rd_data(rd_data)
  );




endmodule
