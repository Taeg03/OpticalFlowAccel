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
reg signed [15:0] ix4 = 0;
reg signed [15:0] iy4 = 0;
reg signed [15:0] it4 = 0;

reg valid_in8 = 0;
reg signed [15:0] ix8 = 0;
reg signed [15:0] iy8 = 0;
reg signed [15:0] it8 = 0;

wire valid_out4;
wire signed [31:0] sxx4;
wire signed [31:0] sxy4;
wire signed [31:0] syy4;
wire signed [31:0] sxt4;
wire signed [31:0] syt4;

wire valid_out8;
wire signed [31:0] sxx8;
wire signed [31:0] sxy8;
wire signed [31:0] syy8;
wire signed [31:0] sxt8;
wire signed [31:0] syt8;

tensor_accel #(
    .DATA_W(16),
    .ACC_W(32),
    .IMG_W(IMG_W4)
) dut_w4 (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in4),
    .ix(ix4),
    .iy(iy4),
    .it(it4),
    .valid_out(valid_out4),
    .sxx(sxx4),
    .sxy(sxy4), .syy(syy4), .sxt(sxt4), .syt(syt4)
);

tensor_accel #(
    .DATA_W(16),
    .ACC_W(32),
    .IMG_W(IMG_W8)
) dut_w8 (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in8),
    .ix(ix8),
    .iy(iy8),
    .it(it8),
    .valid_out(valid_out8),
    .sxx(sxx8),
    .sxy(sxy8), .syy(syy8), .sxt(sxt8), .syt(syt8)
);

/* clock */
always #5 clk = ~clk;

integer i;
integer max_sxx4;
integer max_sxx8;
integer max_sxy4;
integer max_sxy8;
integer max_syy4;
integer max_syy8;
integer min_sxt4;
integer min_sxt8;
integer min_syt4;
integer min_syt8;
integer err_count;

task reset_stats;
    begin
        max_sxx4 = -2147483647;
        max_sxx8 = -2147483647;
        max_sxy4 = -2147483647;
        max_sxy8 = -2147483647;
        max_syy4 = -2147483647;
        max_syy8 = -2147483647;
        min_sxt4 = 2147483647;
        min_sxt8 = 2147483647;
        min_syt4 = 2147483647;
        min_syt8 = 2147483647;
    end
endtask

task drive_w4;
    input integer npix;
    input signed [15:0] ixv;
    input signed [15:0] iyv;
    input signed [15:0] itv;
    begin
        for (i = 0; i < npix; i = i + 1) begin
            @(negedge clk);
            valid_in4 = 1;
            ix4 = ixv;
            iy4 = iyv;
            it4 = itv;
        end
        @(negedge clk);
        valid_in4 = 0;
        ix4 = 0;
        iy4 = 0;
        it4 = 0;
    end
endtask

task drive_w8;
    input integer npix;
    input signed [15:0] ixv;
    input signed [15:0] iyv;
    input signed [15:0] itv;
    begin
        for (i = 0; i < npix; i = i + 1) begin
            @(negedge clk);
            valid_in8 = 1;
            ix8 = ixv;
            iy8 = iyv;
            it8 = itv;
        end
        @(negedge clk);
        valid_in8 = 0;
        ix8 = 0;
        iy8 = 0;
        it8 = 0;
    end
endtask

initial begin
    $display("Starting tensor_accel dual-width regression (all tensor outputs)");

    err_count = 0;

    #10 rst = 0;

    /* Phase A: ix=1, iy=0, it=0 */
    reset_stats();

    drive_w4(NPIX4, 16'sd1, 16'sd0, 16'sd0);
    repeat (10) @(negedge clk);

    if ((max_sxx4 == 20) && (max_sxy4 == 0) && (max_syy4 == 0) && (min_sxt4 == 0) && (min_syt4 == 0))
        $display("PASS[A]: IMG_W=4 peaks sxx/sxy/syy=%0d/%0d/%0d mins sxt/syt=%0d/%0d", max_sxx4, max_sxy4, max_syy4, min_sxt4, min_syt4);
    else begin
        $display("FAIL[A]: IMG_W=4 got sxx/sxy/syy=%0d/%0d/%0d sxt/syt(min)=%0d/%0d exp 20/0/0/0/0", max_sxx4, max_sxy4, max_syy4, min_sxt4, min_syt4);
        err_count = err_count + 1;
    end

    drive_w8(NPIX8, 16'sd1, 16'sd0, 16'sd0);
    repeat (15) @(negedge clk);

    if ((max_sxx8 == 25) && (max_sxy8 == 0) && (max_syy8 == 0) && (min_sxt8 == 0) && (min_syt8 == 0))
        $display("PASS[A]: IMG_W=8 peaks sxx/sxy/syy=%0d/%0d/%0d mins sxt/syt=%0d/%0d", max_sxx8, max_sxy8, max_syy8, min_sxt8, min_syt8);
    else begin
        $display("FAIL[A]: IMG_W=8 got sxx/sxy/syy=%0d/%0d/%0d sxt/syt(min)=%0d/%0d exp 25/0/0/0/0", max_sxx8, max_sxy8, max_syy8, min_sxt8, min_syt8);
        err_count = err_count + 1;
    end

    /* Phase B: ix=2, iy=3, it=-1 */
    reset_stats();

    drive_w4(NPIX4, 16'sd2, 16'sd3, -16'sd1);
    repeat (10) @(negedge clk);

    if ((max_sxx4 == 80) && (max_sxy4 == 120) && (max_syy4 == 180) && (min_sxt4 == -40) && (min_syt4 == -60))
        $display("PASS[B]: IMG_W=4 peaks sxx/sxy/syy=%0d/%0d/%0d mins sxt/syt=%0d/%0d", max_sxx4, max_sxy4, max_syy4, min_sxt4, min_syt4);
    else begin
        $display("FAIL[B]: IMG_W=4 got sxx/sxy/syy=%0d/%0d/%0d sxt/syt(min)=%0d/%0d exp 80/120/180/-40/-60", max_sxx4, max_sxy4, max_syy4, min_sxt4, min_syt4);
        err_count = err_count + 1;
    end

    drive_w8(NPIX8, 16'sd2, 16'sd3, -16'sd1);
    repeat (15) @(negedge clk);

    if ((max_sxx8 == 100) && (max_sxy8 == 150) && (max_syy8 == 225) && (min_sxt8 == -50) && (min_syt8 == -75))
        $display("PASS[B]: IMG_W=8 peaks sxx/sxy/syy=%0d/%0d/%0d mins sxt/syt=%0d/%0d", max_sxx8, max_sxy8, max_syy8, min_sxt8, min_syt8);
    else begin
        $display("FAIL[B]: IMG_W=8 got sxx/sxy/syy=%0d/%0d/%0d sxt/syt(min)=%0d/%0d exp 100/150/225/-50/-75", max_sxx8, max_sxy8, max_syy8, min_sxt8, min_syt8);
        err_count = err_count + 1;

    end

    if (err_count != 0) begin
        $fatal(1, "Regression FAILED with %0d error(s)", err_count);
    end else begin
        $display("PASS: all tensor_accel regression checks");
    end

    #10 $finish;
end

/* monitor */
always @(posedge clk) begin
    if (!rst) begin
        if (valid_out4 && (^sxx4 === 1'bx)) begin
            err_count = err_count + 1;
            $fatal(1, "W4 produced X on sxx at t=%0t", $time);
        end
        if (valid_out4 && ((^sxy4 === 1'bx) || (^syy4 === 1'bx) || (^sxt4 === 1'bx) || (^syt4 === 1'bx))) begin
            err_count = err_count + 1;
            $fatal(1, "W4 produced X on one of {sxy,syy,sxt,syt} at t=%0t", $time);
        end
        if (valid_out8 && (^sxx8 === 1'bx)) begin
            err_count = err_count + 1;
            $fatal(1, "W8 produced X on sxx at t=%0t", $time);
        end
        if (valid_out8 && ((^sxy8 === 1'bx) || (^syy8 === 1'bx) || (^sxt8 === 1'bx) || (^syt8 === 1'bx))) begin
            err_count = err_count + 1;
            $fatal(1, "W8 produced X on one of {sxy,syy,sxt,syt} at t=%0t", $time);
        end

        if (valid_out4 && sxx4 > max_sxx4)
            max_sxx4 <= sxx4;
        if (valid_out4 && sxy4 > max_sxy4)
            max_sxy4 <= sxy4;
        if (valid_out4 && syy4 > max_syy4)
            max_syy4 <= syy4;
        if (valid_out4 && sxt4 < min_sxt4)
            min_sxt4 <= sxt4;
        if (valid_out4 && syt4 < min_syt4)
            min_syt4 <= syt4;

        if (valid_out8 && sxx8 > max_sxx8)
            max_sxx8 <= sxx8;
        if (valid_out8 && sxy8 > max_sxy8)
            max_sxy8 <= sxy8;
        if (valid_out8 && syy8 > max_syy8)
            max_syy8 <= syy8;
        if (valid_out8 && sxt8 < min_sxt8)
            min_sxt8 <= sxt8;
        if (valid_out8 && syt8 < min_syt8)
            min_syt8 <= syt8;

        if (valid_out4) begin
            $strobe("[W4] t=%0t sxx=%0d sxy=%0d syy=%0d sxt=%0d syt=%0d", $time, sxx4, sxy4, syy4, sxt4, syt4);
        end
        if (valid_out8) begin
            $strobe("[W8] t=%0t sxx=%0d sxy=%0d syy=%0d sxt=%0d syt=%0d", $time, sxx8, sxy8, syy8, sxt8, syt8);
        end
    end
end

endmodule