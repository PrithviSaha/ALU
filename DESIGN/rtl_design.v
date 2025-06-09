`include "defines.v"

module ALU #(parameter WIDTH = 8)(CLK, RST, INP_VALID, CE, MODE, CMD, OPA, OPB, CIN, ERR, RES, OFLOW, COUT, G, L, E);
    localparam RES_WIDTH = 2*WIDTH;
    input CLK, RST, MODE, CE, CIN;
    input [WIDTH-1:0] OPA, OPB;
    input [1:0] INP_VALID;
    input [3:0] CMD;
    output reg ERR, OFLOW, COUT, G, L, E;
    output reg [RES_WIDTH:0] RES;

    //reg [2*WIDTH:0] MUL;
    reg signed [WIDTH-1:0] signed_OPA, signed_OPB;
    reg [WIDTH:0] sum, sum_cin, sub_cin;
    reg signed [WIDTH:0] signed_sum, signed_sub;
    reg [$clog2(WIDTH)-1:0] rot_amt;
    /*
    rot_amt = OPB[$clog2(WIDTH)-1:0];
    sum = OPA + OPB;
    sum_cin = OPA + OPB + CIN;
    */
    always@(*) begin
        signed_OPA = $signed(OPA);
        signed_OPB = $signed(OPB);
        if(MODE) begin
            if(CMD == `ADD)
                sum = OPA + OPB;
            else if(CMD == `ADD_CIN)
                sum_cin = OPA + OPB + CIN;
            else if(CMD == `SUB_CIN)
                sub_cin = ((OPA - OPB) - CIN) & ((1 << (WIDTH+1)) - 1);
            else if(CMD == `SIGNED_ADD)
                signed_sum = (signed_OPA + signed_OPB) & ((1 << (WIDTH+1)) - 1);
            else if(CMD == `SIGNED_SUB)
                signed_sub = (signed_OPA - signed_OPB) & ((1 << (WIDTH+1)) - 1);
        end
        else begin
            if(CMD == `ROL_A_B || CMD == `ROR_A_B)
                rot_amt = OPB[$clog2(WIDTH)-1:0];
        end
    end

    always@(posedge CLK or posedge RST) begin
        if(RST) begin
            RES <= {RES_WIDTH{1'b0}};
            COUT <= 1'b0;
            OFLOW <= 1'b0;
            G <= 1'b0;
            L <= 1'b0;
            E <= 1'b0;
            ERR <= 1'b0;
        end
        else if(CE) begin
            if(MODE) begin                      //Arithmetic
                RES <= {RES_WIDTH{1'b0}};
                COUT <= 1'b0;
                OFLOW <= 1'b0;
                G <= 1'b0;
                E <= 1'b0;
                L <= 1'b0;
                ERR <= 1'b0;

                case(INP_VALID)
                    2'b00: begin
                        RES <= 0;
                        COUT <= 0;
                        OFLOW <= 0;
                        ERR <= 1'b1;
                    end
                    2'b01: begin                // When only OPB is enabled
                        case(CMD)
                            `INC_B: begin                       //INC_B
                                if(OPB == {WIDTH{1'b1}})
                                    COUT <= 1'b1;
                                RES <= OPB + 1;
                            end
                            `DEC_B: begin                       //DEC_B
                                if(OPB == {WIDTH{1'b0}})
                                    OFLOW <= 1'b1;
                                RES <= (OPB - 1) & ((1 << (WIDTH+1)) - 1);
                            end
                            default: ERR <= 1'b1;
                        endcase
                    end
                    2'b10: begin                // When only OPA is enabled
                        case(CMD)
                            `INC_A: begin                       //INC_A
                                if(OPA == {WIDTH{1'b1}})
                                    COUT <= 1'b1;
                                RES <= OPA + 1;
                            end
                            `DEC_A: begin                       //DEC_A
                                if(OPA == {WIDTH{1'b0}})
                                    OFLOW <= 1'b1;
                                RES <= (OPA - 1) & ((1 << (WIDTH+1)) - 1);
                            end
                            default: ERR <= 1'b1;
                        endcase
                    end
                    2'b11: begin
                        case(CMD)
                            `ADD: begin                 //ADD
                                RES <= sum;
                                COUT <= sum[WIDTH] ? 1 : 0;
                            end
                            `SUB: begin                 //SUB
                                RES <= (OPA - OPB) & ((1 << (WIDTH+1)) - 1);
                                OFLOW <= (OPA < OPB) ? 1 : 0;
                            end
                            `ADD_CIN: begin             //ADD_CIN
                                RES <= sum_cin;
                                COUT <= sum_cin[WIDTH] ? 1 : 0;
                            end
                            `SUB_CIN: begin             //SUB_CIN
                                RES <= sub_cin;
                                //OFLOW <= ((OPA - OPB) < CIN) ? 1 : 0;
                                OFLOW <= (OPA < (OPB + CIN)) ? 1 : 0;
                            end
                            `CMP: begin                 //CMP
                                if(OPA > OPB) begin
                                    G <= 1'b1;
                                end
                                if(OPA == OPB) begin
                                    E <= 1'b1;
                                end
                                if(OPA < OPB) begin
                                    L <= 1'b1;
                                end
                            end
                            `INC_MUL: begin             //INC both and MUL
                                if(OPA == {WIDTH{1'b1}} || OPB == {WIDTH{1'b1}})
                                    ERR <= 1'b1;
                                else
                                    RES <= (OPA + 1) * (OPB + 1);
                            end
                            `SHL1_MUL: begin            //SHL1_A and MUL with OPB
                                RES <= ((OPA << 1) & ((1 << WIDTH)-1)) * OPB;
                            end
                            `SIGNED_ADD: begin          //signed ADD
                                RES <= signed_sum;
                                COUT <= signed_sum[WIDTH] ? 1 : 0;
                                G <= (signed_OPA > signed_OPB) ? 1'b1 : 1'b0;
                                E <= (signed_OPA == signed_OPB) ? 1'b1 : 1'b0;
                                L <= (signed_OPA < signed_OPB) ? 1'b1 : 1'b0;
                            end
                            `SIGNED_SUB: begin          //signed SUB
                                RES <= signed_sub & ((1 << (WIDTH+1)) - 1);
                                COUT <= signed_sub[WIDTH] ? 1 : 0;
                                if((OPA[WIDTH-1] != OPB[WIDTH-1]) && (signed_sub[WIDTH-1] != OPA[WIDTH-1]))
                                    OFLOW <= 1'b1;
                                else
                                    OFLOW <= 1'b0;
                                G <= (signed_OPA > signed_OPB) ? 1'b1 : 1'b0;
                                E <= (signed_OPA == signed_OPB) ? 1'b1 : 1'b0;
                                L <= (signed_OPA < signed_OPB) ? 1'b1 : 1'b0;
                            end
                            default: begin
                                ERR <= 1'b1;
                            end
                        endcase
                    end
                endcase
            end
            else begin                                  //Logical
                RES <= {RES_WIDTH{1'b0}};
                COUT <= 1'b0;
                OFLOW <= 1'b0;
                G <= 1'b0;
                E <= 1'b0;
                L <= 1'b0;
                ERR <= 1'b0;

                case(INP_VALID)
                    2'b00: begin                        //both inputs disabled
                        RES <= 0;
                        COUT <= 0;
                        OFLOW <= 0;
                        ERR <= 1'b1;
                    end
                    2'b01: begin                        //only OPB is enabled
                        case(CMD)
                            `NOT_B: RES <= !OPB;        //NOT_B
                            `SHR1_B: RES <= OPB >> 1;   //SHR1_B
                            `SHL1_B: RES <= ((OPB << 1) & ((1 << WIDTH) - 1));  //SHL1_B
                            default: ERR <= 1'b1;
                        endcase
                    end
                    2'b10: begin                        //only OPA is enabled
                        case(CMD)
                            `NOT_A: RES <= !OPA;                                //NOT_A
                            `SHR1_A: RES <= OPA >> 1;                           //SHR1_A
                            `SHL1_A: RES <= ((OPA << 1) & ((1 << WIDTH) - 1));  //SHL1_A
                            default: ERR <= 1'b1;
                        endcase
                    end
                    2'b11: begin                        //both enabled
                        case(CMD)
                            `AND: RES <= OPA && OPB;                    //AND
                            `NAND: RES <= {{(RES_WIDTH){1'b0}}, ~((|OPA) && (|OPB))};           //NAND
                            `OR: RES <= OPA || OPB;                     //OR
                            `NOR: RES <= {{(RES_WIDTH){1'b0}}, ~((|OPA) || (|OPB))};                    //NOR
                            `XOR: RES <= OPA ^ OPB;             //XOR
                            `XNOR: RES <= {{(RES_WIDTH){1'b0}}, ~(OPA ^ OPB)};          //XNOR
                            `ROL_A_B: begin                             //ROL_A_B
                                if(|OPB[WIDTH-1:$clog2(WIDTH)+1])       //dynamic checking for MSB using clog2 from WIDTH-1 to $clog2(WIDTH)+1
                                    ERR <= 1'b1;
                                //rot_amt = OPB[$clog2(WIDTH)-1:0];
                                RES <= ((OPA << rot_amt) | (OPA >> (WIDTH-rot_amt))) & ((1 << WIDTH)-1);
                        /*      casez(OPB)
                                    8'b0000_?000: RES <= OPA;
                                    8'b0000_?001: RES <= {OPA[WIDTH-2:0], OPA[WIDTH-1]};
                                    8'b0000_?010: RES <= {OPA[WIDTH-3:0], OPA[WIDTH-1:WIDTH-2]};
                                    8'b0000_?011: RES <= {OPA[WIDTH-4:0], OPA[WIDTH-1:WIDTH-3]};
                                    8'b0000_?100: RES <= {OPA[WIDTH-5:0], OPA[WIDTH-1:WIDTH-4]};
                                    8'b0000_?101: RES <= {OPA[WIDTH-6:0], OPA[WIDTH-1:WIDTH-5]};
                                    8'b0000_?110: RES <= {OPA[WIDTH-7:0], OPA[WIDTH-1:WIDTH-6]};
                                    8'b0000_?111: RES <= {OPA[WIDTH-8:0], OPA[WIDTH-1:WIDTH-7]};
                                endcase
                        */
                            end
                            `ROR_A_B: begin                             //ROR_A_B
                                if(|OPB[WIDTH-1:$clog2(WIDTH)+1])
                                    ERR <= 1'b1;
                                //rot_amt = OPB[$clog2(WIDTH)-1:0];
                                RES <= ((OPA >> rot_amt) | (OPA << (WIDTH-rot_amt))) & ((1 << WIDTH)-1);
                        /*      casez(OPB)
                                    8'b0000_?000: RES <= OPA;
                                    8'b0000_?001: RES <= {OPA[0], OPA[WIDTH-1:1]};
                                    8'b0000_?010: RES <= {OPA[1:0], OPA[WIDTH-1:2]};
                                    8'b0000_?011: RES <= {OPA[2:0], OPA[WIDTH-1:3]};
                                    8'b0000_?100: RES <= {OPA[3:0], OPA[WIDTH-1:4]};
                                    8'b0000_?101: RES <= {OPA[4:0], OPA[WIDTH-1:5]};
                                    8'b0000_?110: RES <= {OPA[5:0], OPA[WIDTH-1:6]};
                                    8'b0000_?111: RES <= {OPA[6:0], OPA[WIDTH-1:7]};
                                endcase
                        */
                            end
                            default: ERR <= 1'b1;
                        endcase
                    end
                endcase
            end
        end
    end

endmodule
