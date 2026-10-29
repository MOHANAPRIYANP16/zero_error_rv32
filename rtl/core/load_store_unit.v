`timescale 1ns / 1ps

module load_store_unit (
    input  wire [2:0]  funct3,
    input  wire [1:0]  byte_offset,
    input  wire [31:0] rs2_data,
    input  wire [31:0] raw_rdata,
    input  wire        MemWrite,
    output reg  [3:0]  byte_en,
    output reg  [31:0] write_data_mem,
    output reg  [31:0] formatted_load_data
);

    // Store logic
    always @(*) begin
        byte_en        = 4'b0000;
        write_data_mem = 32'd0;

        if (MemWrite) begin
            case (funct3[1:0])
                2'b00: begin // SB
                    case (byte_offset)
                        2'b00: begin byte_en = 4'b0001; write_data_mem = {24'd0, rs2_data[7:0]}; end
                        2'b01: begin byte_en = 4'b0010; write_data_mem = {16'd0, rs2_data[7:0], 8'd0}; end
                        2'b10: begin byte_en = 4'b0100; write_data_mem = {8'd0, rs2_data[7:0], 16'd0}; end
                        2'b11: begin byte_en = 4'b1000; write_data_mem = {rs2_data[7:0], 24'd0}; end
                    endcase
                end

                2'b01: begin // SH
                    if (byte_offset[1]) begin
                        byte_en        = 4'b1100;
                        write_data_mem = {rs2_data[15:0], 16'd0};
                    end else begin
                        byte_en        = 4'b0011;
                        write_data_mem = {16'd0, rs2_data[15:0]};
                    end
                end

                2'b10: begin // SW
                    byte_en        = 4'b1111;
                    write_data_mem = rs2_data;
                end

                default: begin
                    byte_en        = 4'b1111;
                    write_data_mem = rs2_data;
                end
            endcase
        end
    end

    // Load logic
    reg [7:0]  selected_byte;
    reg [15:0] selected_half;

    always @(*) begin
        case (byte_offset)
            2'b00:   selected_byte = raw_rdata[7:0];
            2'b01:   selected_byte = raw_rdata[15:8];
            2'b10:   selected_byte = raw_rdata[23:16];
            2'b11:   selected_byte = raw_rdata[31:24];
        endcase

        if (byte_offset[1])
            selected_half = raw_rdata[31:16];
        else
            selected_half = raw_rdata[15:0];

        case (funct3)
            3'b000:  formatted_load_data = {{24{selected_byte[7]}}, selected_byte}; // LB
            3'b001:  formatted_load_data = {{16{selected_half[15]}}, selected_half}; // LH
            3'b010:  formatted_load_data = raw_rdata;                               // LW
            3'b100:  formatted_load_data = {24'd0, selected_byte};                  // LBU
            3'b101:  formatted_load_data = {16'd0, selected_half};                  // LHU
            default: formatted_load_data = raw_rdata;
        endcase
    end

endmodule


// `timescale 1ns / 1ps

// module load_store_unit (
//     input  wire [2:0]  funct3,
//     input  wire [1:0]  byte_offset,
//     input  wire [31:0] rs2_data,
//     input  wire [31:0] raw_rdata,
//     input  wire        MemWrite,
//     output reg  [3:0]  byte_en,
//     output reg  [31:0] write_data_mem,
//     output reg  [31:0] formatted_load_data
// );

//     // Store formatting & byte write strobe generation
//     always @(*) begin
//         byte_en        = 4'b0000;
//         write_data_mem = 32'd0;

//         if (MemWrite) begin
//             case (funct3[1:0])
//                 2'b00: begin // SB
//                     case (byte_offset)
//                         2'b00: begin byte_en = 4'b0001; write_data_mem = {24'd0, rs2_data[7:0]}; end
//                         2'b01: begin byte_en = 4'b0010; write_data_mem = {16'd0, rs2_data[7:0], 8'd0}; end
//                         2'b10: begin byte_en = 4'b0100; write_data_mem = {8'd0, rs2_data[7:0], 16'd0}; end
//                         2'b11: begin byte_en = 4'b1000; write_data_mem = {rs2_data[7:0], 24'd0}; end
//                     endcase
//                 end

//                 2'b01: begin // SH
//                     if (byte_offset[1]) begin
//                         byte_en        = 4'b1100;
//                         write_data_mem = {rs2_data[15:0], 16'd0};
//                     end else begin
//                         byte_en        = 4'b0011;
//                         write_data_mem = {16'd0, rs2_data[15:0]};
//                     end
//                 end

//                 2'b10: begin // SW
//                     byte_en        = 4'b1111;
//                     write_data_mem = rs2_data;
//                 end

//                 default: begin
//                     byte_en        = 4'b1111;
//                     write_data_mem = rs2_data;
//                 end
//             endcase
//         end
//     end

// //Load formatting 
	
// 	always @(*) begin
//         case (funct3)
//             3'b000:  
// 			begin 
// 				case(byte_offset)
// 				2'b00 : formatted_load_data = {{24{raw_rdata[7]}}, raw_rdata[7:0]};// LB
// 				2'b01 : formatted_load_data = {{24{raw_rdata[15]}}, raw_rdata[15:8]};
// 				2'b10 : formatted_load_data = {{24{raw_rdata[23]}}, raw_rdata[23:16]};
// 				2'b11 : formatted_load_data = {{24{raw_rdata[31]}}, raw_rdata[31:24]};
// 				default : formatted_load_data = raw_rdata;
// 				endcase
// 			end
//             3'b001:  
// 			begin	
// 				if (byte_offset[1]) 
// 						formatted_load_data = {{16{raw_rdata[31]}},raw_rdata[31:16]};// LH
// 				else	
// 						formatted_load_data = {{16{raw_rdata[15]}},raw_rdata[15:0]};
// 			end
//             3'b010:  formatted_load_data = raw_rdata;                               // LW
//             3'b100:  
// 			begin
// 				case(byte_offset)
// 				2'b00 : formatted_load_data = {24'd0, raw_rdata[7:0]};// LBU
// 				2'b01 : formatted_load_data = {24'd0, raw_rdata[15:8]};
// 				2'b10 : formatted_load_data = {24'd0, raw_rdata[23:16]};
// 				2'b11 : formatted_load_data = {24'd0, raw_rdata[31:24]};
// 				default : formatted_load_data = raw_rdata;
// 				endcase
// 			end
				
//             3'b101:  begin	
// 				if (byte_offset[1]) 
// 						formatted_load_data = {16'd0,raw_rdata[31:16]};// LHU
// 				else	
// 						formatted_load_data = {16'd0,raw_rdata[15:0]};
// 			end
//             default: formatted_load_data = raw_rdata;
//         endcase
//     end

// endmodule
