module cordic_top #(parameter WIDTH = 16, parameter N = 16)(
    input  logic signed [WIDTH-1:0] x_input,
    input  logic signed [WIDTH-1:0] y_input,
    input  logic signed [WIDTH-1:0] z_input,
    input  logic valid_input,
    input  logic clk,
    input  logic rst_n,
    input  logic mode,
    output logic signed [WIDTH-1:0] x_output,
    output logic signed [WIDTH-1:0] y_output,
    output logic signed [WIDTH-1:0] z_output,
    output logic                valid_output
    );
    
    logic signed [WIDTH-1:0] x_pipe [0:N];
    logic signed [WIDTH-1:0] y_pipe [0:N];
    logic signed [WIDTH-1:0] z_pipe [0:N];
    logic valid_pipe [0:N];
    
    assign x_pipe[0] = x_input;
    assign y_pipe[0] = y_input;
    assign z_pipe[0] = z_input;
    assign valid_pipe[0] = valid_input;
    
    genvar i;
    generate 
        for (i=0; i<N; i++) begin : Stages
            cordic_stage #(.WIDTH(WIDTH), .STAGE(i)) cs(
                .clk(clk),
                .rst_n(rst_n),
                .mode(mode),
                .x_in(x_pipe[i]),
                .y_in(y_pipe[i]),
                .z_in(z_pipe[i]),
                .valid_in(valid_pipe[i]),
                .x_out(x_pipe[i+1]),
                .y_out(y_pipe[i+1]),
                .z_out(z_pipe[i+1]),
                .valid_out(valid_pipe[i+1])
            );    
        end
    endgenerate
    
    assign x_output = x_pipe[N];
    assign y_output = y_pipe[N];
    assign z_output = z_pipe[N];
    assign valid_output = valid_pipe[N];
    
    
endmodule
