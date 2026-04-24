`timescale 1ns / 1ps

module tensor_accel #(
    parameter DATA_W = 16,
    parameter ACC_W  = 32,
    parameter IMG_W  = 128
)(
    input  wire clk,
    input  wire rst,

    input  wire valid_in,

    input  wire signed [DATA_W-1:0] ix,
    input  wire signed [DATA_W-1:0] iy,
    input  wire signed [DATA_W-1:0] it,

    output wire valid_out,

    output wire signed [ACC_W-1:0] sxx,
    output wire signed [ACC_W-1:0] sxy,
    output wire signed [ACC_W-1:0] syy,
    output wire signed [ACC_W-1:0] sxt,
    output wire signed [ACC_W-1:0] syt
);

///////////////////////////////////////////////////////////////
// Stage 1: gradient products (keep your code)
///////////////////////////////////////////////////////////////

reg signed [ACC_W-1:0] ixix;
reg signed [ACC_W-1:0] ixiy;
reg signed [ACC_W-1:0] iyiy;
reg signed [ACC_W-1:0] ixit;
reg signed [ACC_W-1:0] iyit;

reg valid_stage1;

always @(posedge clk) begin
    if (rst) begin
        ixix <= 0;
        ixiy <= 0;
        iyiy <= 0;
        ixit <= 0;
        iyit <= 0;
        valid_stage1 <= 0;
    end else begin
        if (valid_in) begin
            ixix <= ix * ix;
            ixiy <= ix * iy;
            iyiy <= iy * iy;
            ixit <= ix * it;
            iyit <= iy * it;
        end else begin
            ixix <= 0;
            ixiy <= 0;
            iyiy <= 0;
            ixit <= 0;
            iyit <= 0;
        end
        valid_stage1 <= valid_in;
    end
end

///////////////////////////////////////////////////////////////
// Stage 2-4: box filter pipelines for all tensor products
///////////////////////////////////////////////////////////////

wire signed [ACC_W-1:0] hsum_sxx;
wire signed [ACC_W-1:0] hsum_sxy;
wire signed [ACC_W-1:0] hsum_syy;
wire signed [ACC_W-1:0] hsum_sxt;
wire signed [ACC_W-1:0] hsum_syt;

wire valid_stage2_sxx;
wire valid_stage2_sxy;
wire valid_stage2_syy;
wire valid_stage2_sxt;
wire valid_stage2_syt;

box_filter_h5 #(
    .DATA_W(ACC_W),
    .IMG_W(IMG_W)
) h_sxx (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage1),
    .pixel_in(ixix),
    .valid_out(valid_stage2_sxx),
    .sum_out(hsum_sxx)
);

box_filter_h5 #(
    .DATA_W(ACC_W),
    .IMG_W(IMG_W)
) h_sxy (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage1),
    .pixel_in(ixiy),
    .valid_out(valid_stage2_sxy),
    .sum_out(hsum_sxy)
);

box_filter_h5 #(
    .DATA_W(ACC_W),
    .IMG_W(IMG_W)
) h_syy (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage1),
    .pixel_in(iyiy),
    .valid_out(valid_stage2_syy),
    .sum_out(hsum_syy)
);

box_filter_h5 #(
    .DATA_W(ACC_W),
    .IMG_W(IMG_W)
) h_sxt (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage1),
    .pixel_in(ixit),
    .valid_out(valid_stage2_sxt),
    .sum_out(hsum_sxt)
);

box_filter_h5 #(
    .DATA_W(ACC_W),
    .IMG_W(IMG_W)
) h_syt (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage1),
    .pixel_in(iyit),
    .valid_out(valid_stage2_syt),
    .sum_out(hsum_syt)
);

wire signed [ACC_W-1:0] r0_sxx, r1_sxx, r2_sxx, r3_sxx, r4_sxx;
wire signed [ACC_W-1:0] r0_sxy, r1_sxy, r2_sxy, r3_sxy, r4_sxy;
wire signed [ACC_W-1:0] r0_syy, r1_syy, r2_syy, r3_syy, r4_syy;
wire signed [ACC_W-1:0] r0_sxt, r1_sxt, r2_sxt, r3_sxt, r4_sxt;
wire signed [ACC_W-1:0] r0_syt, r1_syt, r2_syt, r3_syt, r4_syt;

wire valid_stage3_sxx;
wire valid_stage3_sxy;
wire valid_stage3_syy;
wire valid_stage3_sxt;
wire valid_stage3_syt;

line_buffer_5 #(
    .DATA_W(ACC_W),
    .IMG_W(IMG_W)
) lb_sxx (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage2_sxx),
    .din(hsum_sxx),
    .valid_out(valid_stage3_sxx),
    .r0(r0_sxx), .r1(r1_sxx), .r2(r2_sxx), .r3(r3_sxx), .r4(r4_sxx)
);

line_buffer_5 #(
    .DATA_W(ACC_W),
    .IMG_W(IMG_W)
) lb_sxy (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage2_sxy),
    .din(hsum_sxy),
    .valid_out(valid_stage3_sxy),
    .r0(r0_sxy), .r1(r1_sxy), .r2(r2_sxy), .r3(r3_sxy), .r4(r4_sxy)
);

line_buffer_5 #(
    .DATA_W(ACC_W),
    .IMG_W(IMG_W)
) lb_syy (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage2_syy),
    .din(hsum_syy),
    .valid_out(valid_stage3_syy),
    .r0(r0_syy), .r1(r1_syy), .r2(r2_syy), .r3(r3_syy), .r4(r4_syy)
);

line_buffer_5 #(
    .DATA_W(ACC_W),
    .IMG_W(IMG_W)
) lb_sxt (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage2_sxt),
    .din(hsum_sxt),
    .valid_out(valid_stage3_sxt),
    .r0(r0_sxt), .r1(r1_sxt), .r2(r2_sxt), .r3(r3_sxt), .r4(r4_sxt)
);

line_buffer_5 #(
    .DATA_W(ACC_W),
    .IMG_W(IMG_W)
) lb_syt (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage2_syt),
    .din(hsum_syt),
    .valid_out(valid_stage3_syt),
    .r0(r0_syt), .r1(r1_syt), .r2(r2_syt), .r3(r3_syt), .r4(r4_syt)
);

wire signed [ACC_W-1:0] vsum_sxx;
wire signed [ACC_W-1:0] vsum_sxy;
wire signed [ACC_W-1:0] vsum_syy;
wire signed [ACC_W-1:0] vsum_sxt;
wire signed [ACC_W-1:0] vsum_syt;

wire valid_stage4_sxx;
wire valid_stage4_sxy;
wire valid_stage4_syy;
wire valid_stage4_sxt;
wire valid_stage4_syt;
wire valid_stage4_unused;

box_filter_v5 #(.DATA_W(ACC_W)) v_sxx (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage3_sxx),
    .r0(r0_sxx), .r1(r1_sxx), .r2(r2_sxx), .r3(r3_sxx), .r4(r4_sxx),
    .valid_out(valid_stage4_sxx),
    .sum_out(vsum_sxx)
);

box_filter_v5 #(.DATA_W(ACC_W)) v_sxy (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage3_sxy),
    .r0(r0_sxy), .r1(r1_sxy), .r2(r2_sxy), .r3(r3_sxy), .r4(r4_sxy),
    .valid_out(valid_stage4_sxy),
    .sum_out(vsum_sxy)
);

box_filter_v5 #(.DATA_W(ACC_W)) v_syy (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage3_syy),
    .r0(r0_syy), .r1(r1_syy), .r2(r2_syy), .r3(r3_syy), .r4(r4_syy),
    .valid_out(valid_stage4_syy),
    .sum_out(vsum_syy)
);

box_filter_v5 #(.DATA_W(ACC_W)) v_sxt (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage3_sxt),
    .r0(r0_sxt), .r1(r1_sxt), .r2(r2_sxt), .r3(r3_sxt), .r4(r4_sxt),
    .valid_out(valid_stage4_sxt),
    .sum_out(vsum_sxt)
);

box_filter_v5 #(.DATA_W(ACC_W)) v_syt (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_stage3_syt),
    .r0(r0_syt), .r1(r1_syt), .r2(r2_syt), .r3(r3_syt), .r4(r4_syt),
    .valid_out(valid_stage4_syt),
    .sum_out(vsum_syt)
);

///////////////////////////////////////////////////////////////
// Outputs
///////////////////////////////////////////////////////////////

assign sxx = vsum_sxx;
assign sxy = vsum_sxy;
assign syy = vsum_syy;
assign sxt = vsum_sxt;
assign syt = vsum_syt;

assign valid_stage4_unused = valid_stage4_sxy | valid_stage4_syy | valid_stage4_sxt | valid_stage4_syt;
assign valid_out = valid_stage4_sxx;

endmodule