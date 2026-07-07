module cordic_stage #(
    parameter int STAGE = 0,
    parameter int WIDTH = 16
)(
    input  logic                clk,
    input  logic                rst_n,
    input  logic                mode,
    input  logic signed [WIDTH-1:0] x_in,
    input  logic signed [WIDTH-1:0] y_in,
    input  logic signed [WIDTH-1:0] z_in,
    input  logic                valid_in,
    output logic signed [WIDTH-1:0] x_out,
    output logic signed [WIDTH-1:0] y_out,
    output logic signed [WIDTH-1:0] z_out,
    output logic                valid_out
);

    localparam logic signed [WIDTH-1:0] ATAN_TABLE [0:15] = '{
        16'h1922,  // arctan(2^0)  = 0.7854 rad | 0.7854 x 2^13 = 'd6434
        16'h0ED6,  // arctan(1/2) = 0.4636 rad  
        16'h07D2,  // arctan(1/4) = 0.2450 rad
        16'h03EB,  // arctan(1/8) = 0.1244 rad
        16'h01FD,  // arctan(2^-4) = 0.0624 rad
        16'h00FF,  // arctan(2^-5) = 0.0312 rad
        16'h007F,  // arctan(2^-6) = 0.0156 rad
        16'h0040,  // arctan(2^-7) = 0.0078 rad
        16'h0020,  // arctan(2^-8) = 0.0039 rad
        16'h0010,  // arctan(2^-9) = 0.0020 rad
        16'h0008,  // arctan(2^-10) = 0.0010 rad
        16'h0004,  // arctan(2^-11) = 0.0005 rad
        16'h0002,  // arctan(2^-12) = 0.0002 rad
        16'h0001,  // arctan(2^-13) = 0.0001 rad
        16'h0001,  // arctan(2^-14) = 0.0001 rad
        16'h0000   // arctan(2^-15) = ~0 rad
    };
    
    
    
    
    logic d_i;
    
    //mode: 0 - vector, 1 - rotation
    assign d_i = mode ? z_in[WIDTH-1] : ~y_in[WIDTH-1];
    
    logic signed [WIDTH-1:0] x_next, y_next, z_next;


    //x_{i+1} = x_i - d_i · y_i · 2⁻⁢ⁱ
    //y_{i+1} = y_i + d_i · x_i · 2⁻⁢ⁱ
    //z_{i+1} = z_i - d_i · arctan(2⁻⁢ⁱ)
    
    assign x_next = d_i ? (x_in + (y_in >>> STAGE)) : (x_in - (y_in >>> STAGE));
    assign y_next = d_i ? (y_in - (x_in >>> STAGE)) : (y_in + (x_in >>> STAGE));
    assign z_next = d_i ? (z_in + ATAN_TABLE[STAGE]) : (z_in - ATAN_TABLE[STAGE]);
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x_out <= 0;
            y_out <= 0;
            z_out <= 0;
            valid_out <= 0;
        end 
        else begin
                x_out <= x_next;
                y_out <= y_next;
                z_out <= z_next;
                valid_out <= valid_in;
        end
    end
    
    
endmodule