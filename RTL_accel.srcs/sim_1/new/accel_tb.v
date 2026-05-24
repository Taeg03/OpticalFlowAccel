`timescale 1ns/1ps

module tb_tensor_accel;

localparam IMG_H  = 5;
localparam IMG_W4 = 4;
localparam IMG_W8 = 8;
localparam NPIX4  = IMG_W4 * IMG_H;
localparam NPIX8  = IMG_W8 * IMG_H;

reg clk = 0;
reg rst = 1;

reg valid_in4 = 0;
reg signed [15:0] ix4 = 0, iy4 = 0, it4 = 0;

reg valid_in8 = 0;
reg signed [15:0] ix8 = 0, iy8 = 0, it8 = 0;

wire valid_out4;
wire signed [31:0] sxx4, sxy4, syy4, sxt4, syt4;

wire valid_out8;
wire signed [31:0] sxx8, sxy8, syy8, sxt8, syt8;

tensor_accel #(.DATA_W(16), .ACC_W(32), .IMG_W(IMG_W4)) dut_w4 (
    .clk(clk), .rst(rst), .valid_in(valid_in4),
    .ix(ix4), .iy(iy4), .it(it4),
    .valid_out(valid_out4),
    .sxx(sxx4), .sxy(sxy4), .syy(syy4), .sxt(sxt4), .syt(syt4)
);

tensor_accel #(.DATA_W(16), .ACC_W(32), .IMG_W(IMG_W8)) dut_w8 (
    .clk(clk), .rst(rst), .valid_in(valid_in8),
    .ix(ix8), .iy(iy8), .it(it8),
    .valid_out(valid_out8),
    .sxx(sxx8), .sxy(sxy8), .syy(syy8), .sxt(sxt8), .syt(syt8)
);

always #5 clk = ~clk;

// -----------------------------------------------------------------------
// Shared state
// -----------------------------------------------------------------------
integer i, j;
integer err_count = 0;

// Phase A/B: peak/trough tracking
integer max_sxx4, max_sxx8, max_sxy4, max_sxy8;
integer max_syy4, max_syy8, min_sxt4, min_sxt8;
integer min_syt4, min_syt8;

// Phase selector and per-pixel output counters
reg  [3:0] phase = 0; // 0=idle 1=A/B 2=C 3=D 4=E
integer    rx8   = 0; // W8 output pixel index (phases C,D)
integer    rx4   = 0; // W4 output pixel index (phase E)

// Precomputed horizontal sums for Phase C:
//   ix[col] = col+1  =>  ixix[col] = (col+1)^2
//   hc[c]   = causal 5-tap running sum of ixix,  IMG_W=8
//   c=0: 1   c=1: 5   c=2: 14   c=3: 30
//   c=4: 55  c=5: 90  c=6: 135  c=7: 190
integer hc [0:7];

// Temporaries used inside the monitor
integer exp_row, exp_col, hfact, vfact;
integer exp_sxx, exp_sxy, exp_syy, exp_sxt, exp_syt;
integer n_new, n_old;

// -----------------------------------------------------------------------
// Tasks
// -----------------------------------------------------------------------
task reset_stats;
    begin
        max_sxx4=-2147483647; max_sxx8=-2147483647;
        max_sxy4=-2147483647; max_sxy8=-2147483647;
        max_syy4=-2147483647; max_syy8=-2147483647;
        min_sxt4= 2147483647; min_sxt8= 2147483647;
        min_syt4= 2147483647; min_syt8= 2147483647;
    end
endtask

task drive_w4;
    input integer npix;
    input signed [15:0] ixv, iyv, itv;
    begin
        for (i = 0; i < npix; i = i+1) begin
            @(negedge clk);
            valid_in4=1; ix4=ixv; iy4=iyv; it4=itv;
        end
        @(negedge clk); valid_in4=0; ix4=0; iy4=0; it4=0;
    end
endtask

task drive_w8;
    input integer npix;
    input signed [15:0] ixv, iyv, itv;
    begin
        for (i = 0; i < npix; i = i+1) begin
            @(negedge clk);
            valid_in8=1; ix8=ixv; iy8=iyv; it8=itv;
        end
        @(negedge clk); valid_in8=0; ix8=0; iy8=0; it8=0;
    end
endtask

// Reset + overwrite line buffer memories with zeros so each phase starts clean.
// The line_buffer_5 rst path does not clear its stored arrays, so we must
// drive 5 full rows of zero pixels after reset to flush old data.
task flush_w8;
    begin
        rst=1; repeat(4) @(negedge clk); rst=0;
        for (i = 0; i < 5*IMG_W8; i = i+1) begin
            @(negedge clk); valid_in8=1; ix8=0; iy8=0; it8=0;
        end
        @(negedge clk); valid_in8=0;
        repeat(8) @(negedge clk); // drain pipeline
    end
endtask

task flush_w4;
    begin
        rst=1; repeat(4) @(negedge clk); rst=0;
        for (i = 0; i < 5*IMG_W4; i = i+1) begin
            @(negedge clk); valid_in4=1; ix4=0; iy4=0; it4=0;
        end
        @(negedge clk); valid_in4=0;
        repeat(8) @(negedge clk);
    end
endtask

// -----------------------------------------------------------------------
// Monitor / checker
// -----------------------------------------------------------------------
always @(posedge clk) begin
    if (!rst) begin

        // X-propagation — always fatal
        if (valid_out4 && (^sxx4===1'bx || ^sxy4===1'bx ||
                           ^syy4===1'bx || ^sxt4===1'bx || ^syt4===1'bx)) begin
            err_count = err_count + 1;
            $fatal(1,"W4 output X at t=%0t", $time);
        end
        if (valid_out8 && (^sxx8===1'bx || ^sxy8===1'bx ||
                           ^syy8===1'bx || ^sxt8===1'bx || ^syt8===1'bx)) begin
            err_count = err_count + 1;
            $fatal(1,"W8 output X at t=%0t", $time);
        end

        case (phase)

            // Phase A/B: track peaks/troughs for uniform-input sanity check
            4'd1: begin
                if (valid_out4) begin
                    if (sxx4>max_sxx4) max_sxx4=sxx4;
                    if (sxy4>max_sxy4) max_sxy4=sxy4;
                    if (syy4>max_syy4) max_syy4=syy4;
                    if (sxt4<min_sxt4) min_sxt4=sxt4;
                    if (syt4<min_syt4) min_syt4=syt4;
                end
                if (valid_out8) begin
                    if (sxx8>max_sxx8) max_sxx8=sxx8;
                    if (sxy8>max_sxy8) max_sxy8=sxy8;
                    if (syy8>max_syy8) max_syy8=syy8;
                    if (sxt8<min_sxt8) min_sxt8=sxt8;
                    if (syt8<min_syt8) min_syt8=syt8;
                end
            end

            // Phase C: per-pixel exact check — ramp ix[col]=col+1, iy=it=0, W8
            // Expected sxx at pixel (row,col) = min(row+1,5) * hc[col]
            // All other outputs must be zero.
            4'd2: begin
                if (valid_out8) begin
                    exp_row = rx8 / IMG_W8;
                    exp_col = rx8 % IMG_W8;
                    vfact   = (exp_row < 5) ? (exp_row+1) : 5;
                    exp_sxx = vfact * hc[exp_col];
                    if (sxx8 !== exp_sxx) begin
                        $display("FAIL[C] (%0d,%0d) sxx=%0d exp=%0d",
                                  exp_row, exp_col, sxx8, exp_sxx);
                        err_count = err_count + 1;
                    end
                    if (sxy8!==0 || syy8!==0 || sxt8!==0 || syt8!==0) begin
                        $display("FAIL[C] (%0d,%0d) sxy/syy/sxt/syt=%0d/%0d/%0d/%0d exp 0",
                                  exp_row, exp_col, sxy8, syy8, sxt8, syt8);
                        err_count = err_count + 1;
                    end
                    rx8 = rx8 + 1;
                end
            end

            // Phase D: two-segment vertical-window slide, W8
            // Rows 0-4: ix=2 (ixix=4,  hsum_full=20)
            // Rows 5-9: ix=5 (ixix=25, hsum_full=125)
            // At row r>=5: n_new=(r-4) rows of ix=5, n_old=(9-r) rows of ix=2
            4'd3: begin
                if (valid_out8) begin
                    exp_row = rx8 / IMG_W8;
                    exp_col = rx8 % IMG_W8;
                    hfact   = (exp_col < 4) ? (exp_col+1) : 5;
                    if (exp_row <= 4) begin
                        exp_sxx = (exp_row+1) * hfact * 4;
                    end else begin
                        n_new   = exp_row - 4;
                        n_old   = 5 - n_new;
                        exp_sxx = n_new*hfact*25 + n_old*hfact*4;
                    end
                    if (sxx8 !== exp_sxx) begin
                        $display("FAIL[D] (%0d,%0d) sxx=%0d exp=%0d",
                                  exp_row, exp_col, sxx8, exp_sxx);
                        err_count = err_count + 1;
                    end
                    if (sxy8!==0 || syy8!==0 || sxt8!==0 || syt8!==0) begin
                        $display("FAIL[D] (%0d,%0d) sxy/syy/sxt/syt=%0d/%0d/%0d/%0d exp 0",
                                  exp_row, exp_col, sxy8, syy8, sxt8, syt8);
                        err_count = err_count + 1;
                    end
                    rx8 = rx8 + 1;
                end
            end

            // Phase E: sign coverage, W4, ix=2 iy=-3 it=1
            // ixix=4 ixiy=-6 iyiy=9 ixit=2 iyit=-3
            // hfact=col+1 (IMG_W4=4, window never fills to 5)
            // vfact=row+1 (IMG_H=5, row 0..4)
            4'd4: begin
                if (valid_out4) begin
                    exp_row = rx4 / IMG_W4;
                    exp_col = rx4 % IMG_W4;
                    hfact   = exp_col + 1;
                    vfact   = exp_row + 1;
                    exp_sxx =  vfact * hfact *  4;
                    exp_sxy =  vfact * hfact * -6;
                    exp_syy =  vfact * hfact *  9;
                    exp_sxt =  vfact * hfact *  2;
                    exp_syt =  vfact * hfact * -3;
                    if (sxx4!==exp_sxx || sxy4!==exp_sxy || syy4!==exp_syy ||
                        sxt4!==exp_sxt || syt4!==exp_syt) begin
                        $display("FAIL[E] (%0d,%0d) got %0d/%0d/%0d/%0d/%0d exp %0d/%0d/%0d/%0d/%0d",
                                  exp_row, exp_col,
                                  sxx4,sxy4,syy4,sxt4,syt4,
                                  exp_sxx,exp_sxy,exp_syy,exp_sxt,exp_syt);
                        err_count = err_count + 1;
                    end
                    rx4 = rx4 + 1;
                end
            end

        endcase
    end
end

// -----------------------------------------------------------------------
// Stimulus
// -----------------------------------------------------------------------
initial begin
    $display("=== tensor_accel regression start ===");
    err_count = 0;
    #10; rst = 0;

    // ------------------------------------------------------------------
    // Phase A: ix=1 iy=0 it=0 — only sxx should be nonzero
    // ------------------------------------------------------------------
    phase = 1;
    reset_stats();

    drive_w4(NPIX4, 16'sd1, 16'sd0, 16'sd0);
    repeat(10) @(negedge clk);
    if (max_sxx4==20 && max_sxy4==0 && max_syy4==0 && min_sxt4==0 && min_syt4==0)
        $display("PASS[A]: W4 sxx peak=%0d", max_sxx4);
    else begin
        $display("FAIL[A]: W4 sxx/sxy/syy=%0d/%0d/%0d sxt/syt=%0d/%0d exp 20/0/0/0/0",
                  max_sxx4,max_sxy4,max_syy4,min_sxt4,min_syt4);
        err_count = err_count+1;
    end

    reset_stats();
    drive_w8(NPIX8, 16'sd1, 16'sd0, 16'sd0);
    repeat(15) @(negedge clk);
    if (max_sxx8==25 && max_sxy8==0 && max_syy8==0 && min_sxt8==0 && min_syt8==0)
        $display("PASS[A]: W8 sxx peak=%0d", max_sxx8);
    else begin
        $display("FAIL[A]: W8 sxx/sxy/syy=%0d/%0d/%0d sxt/syt=%0d/%0d exp 25/0/0/0/0",
                  max_sxx8,max_sxy8,max_syy8,min_sxt8,min_syt8);
        err_count = err_count+1;
    end

    // ------------------------------------------------------------------
    // Phase B: ix=2 iy=3 it=-1 — all five outputs nonzero
    // ------------------------------------------------------------------
    reset_stats();
    drive_w4(NPIX4, 16'sd2, 16'sd3, -16'sd1);
    repeat(10) @(negedge clk);
    if (max_sxx4==80 && max_sxy4==120 && max_syy4==180 && min_sxt4==-40 && min_syt4==-60)
        $display("PASS[B]: W4 sxx/sxy/syy=%0d/%0d/%0d sxt/syt=%0d/%0d",
                  max_sxx4,max_sxy4,max_syy4,min_sxt4,min_syt4);
    else begin
        $display("FAIL[B]: W4 sxx/sxy/syy=%0d/%0d/%0d sxt/syt=%0d/%0d exp 80/120/180/-40/-60",
                  max_sxx4,max_sxy4,max_syy4,min_sxt4,min_syt4);
        err_count = err_count+1;
    end

    reset_stats();
    drive_w8(NPIX8, 16'sd2, 16'sd3, -16'sd1);
    repeat(15) @(negedge clk);
    if (max_sxx8==100 && max_sxy8==150 && max_syy8==225 && min_sxt8==-50 && min_syt8==-75)
        $display("PASS[B]: W8 sxx/sxy/syy=%0d/%0d/%0d sxt/syt=%0d/%0d",
                  max_sxx8,max_sxy8,max_syy8,min_sxt8,min_syt8);
    else begin
        $display("FAIL[B]: W8 sxx/sxy/syy=%0d/%0d/%0d sxt/syt=%0d/%0d exp 100/150/225/-50/-75",
                  max_sxx8,max_sxy8,max_syy8,min_sxt8,min_syt8);
        err_count = err_count+1;
    end

    // ------------------------------------------------------------------
    // Phase C: per-pixel ramp, exact check of every output pixel (W8)
    // ix[col] = col+1, iy=it=0, 8 rows
    // Expected sxx(row,col) = min(row+1,5) * hc[col]
    // All other outputs must be zero.
    // This exercises the horizontal sliding window at every tap position.
    // ------------------------------------------------------------------
    hc[0]=1; hc[1]=5; hc[2]=14; hc[3]=30;
    hc[4]=55; hc[5]=90; hc[6]=135; hc[7]=190;

    phase = 0;
    flush_w8();      // reset + zero-fill line buffer
    rx8   = 0;
    phase = 2;

    for (j = 0; j < 8; j = j+1) begin
        for (i = 0; i < IMG_W8; i = i+1) begin
            @(negedge clk);
            valid_in8=1; ix8=i+1; iy8=0; it8=0;
        end
    end
    @(negedge clk); valid_in8=0; ix8=0; iy8=0; it8=0;
    repeat(8) @(negedge clk);

    phase = 0;
    if (rx8 == 64)
        $display("PASS[C]: all 64 pixels exact (per-col ramp, W8)");
    else begin
        $display("FAIL[C]: expected 64 output pixels, got %0d", rx8);
        err_count = err_count+1;
    end

    // ------------------------------------------------------------------
    // Phase D: two-segment feed, vertical sliding window (W8)
    // Rows 0-4:  ix=2 → ixix=4,  full-window hsum=20
    // Rows 5-9:  ix=5 → ixix=25, full-window hsum=125
    // At row r (5..9): n_new=(r-4) new rows, n_old=(9-r) old rows in window.
    // Verifies that old rows actually drop out of the accumulator.
    // ------------------------------------------------------------------
    phase = 0;
    flush_w8();
    rx8   = 0;
    phase = 3;

    for (j = 0; j < 5; j = j+1)   // rows 0-4: ix=2
        for (i = 0; i < IMG_W8; i = i+1) begin
            @(negedge clk); valid_in8=1; ix8=2; iy8=0; it8=0;
        end
    for (j = 0; j < 5; j = j+1)   // rows 5-9: ix=5
        for (i = 0; i < IMG_W8; i = i+1) begin
            @(negedge clk); valid_in8=1; ix8=5; iy8=0; it8=0;
        end
    @(negedge clk); valid_in8=0; ix8=0; iy8=0; it8=0;
    repeat(8) @(negedge clk);

    phase = 0;
    if (rx8 == 80)
        $display("PASS[D]: all 80 pixels exact (vertical window slide, W8)");
    else begin
        $display("FAIL[D]: expected 80 output pixels, got %0d", rx8);
        err_count = err_count+1;
    end

    // ------------------------------------------------------------------
    // Phase E: sign coverage (W4)
    // ix=2, iy=-3, it=1
    //   ixix=4  ixiy=-6  iyiy=9  ixit=2  iyit=-3
    // IMG_W4=4 so horizontal window never reaches 5 pixels wide:
    //   hfact = col+1  (1..4)
    // IMG_H=5 so vfact = row+1 (1..5)
    // Verifies sxy and syt go negative while sxx and syy stay positive.
    // ------------------------------------------------------------------
    phase = 0;
    flush_w4();
    rx4   = 0;
    phase = 4;

    for (j = 0; j < IMG_H; j = j+1)
        for (i = 0; i < IMG_W4; i = i+1) begin
            @(negedge clk); valid_in4=1; ix4=2; iy4=-3; it4=1;
        end
    @(negedge clk); valid_in4=0; ix4=0; iy4=0; it4=0;
    repeat(8) @(negedge clk);

    phase = 0;
    if (rx4 == NPIX4)
        $display("PASS[E]: all %0d pixels exact (sign coverage, W4)", NPIX4);
    else begin
        $display("FAIL[E]: expected %0d output pixels, got %0d", NPIX4, rx4);
        err_count = err_count+1;
    end

    // ------------------------------------------------------------------
    if (err_count != 0)
        $fatal(1, "Regression FAILED — %0d error(s)", err_count);
    else
        $display("PASS: all regression checks");

    #10; $finish;
end

endmodule
