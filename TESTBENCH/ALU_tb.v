`timescale 1ns/1ps

`include "defines.v"
`include "rtl_design.v"

`define PASS 1'b1
`define FAIL 1'b0
`define no_of_testcase 107

module testbench();

    parameter WIDTH     = 8;
    parameter RES_WIDTH = 2 * WIDTH;

    localparam FEATURE_ID_WIDTH   = WIDTH;
    localparam RST_WIDTH          = 1;
    localparam CE_WIDTH           = 1;
    localparam INP_VALID_WIDTH    = 2;
    localparam MODE_WIDTH         = 1;
    localparam CMD_WIDTH          = 4;
    localparam OPA_WIDTH          = WIDTH;
    localparam OPB_WIDTH          = WIDTH;
    localparam CIN_WIDTH          = 1;
    localparam OFLOW_WIDTH        = 1;
    localparam EGL_WIDTH          = 3;
    localparam ERR_WIDTH          = 1;
    localparam COUT_WIDTH         = 1;
    localparam EXPECTED_RES_WIDTH = RES_WIDTH + 1;

    localparam TOTAL_WIDTH = FEATURE_ID_WIDTH + RST_WIDTH + CE_WIDTH + INP_VALID_WIDTH + MODE_WIDTH + CMD_WIDTH + OPA_WIDTH + OPB_WIDTH + CIN_WIDTH + EXPECTED_RES_WIDTH + COUT_WIDTH + OFLOW_WIDTH + EGL_WIDTH + ERR_WIDTH;

    //testcase widths
    localparam FEATURE_ID_MSB    = TOTAL_WIDTH - 1;
    localparam FEATURE_ID_LSB    = FEATURE_ID_MSB - FEATURE_ID_WIDTH + 1;

    localparam RST_MSB           = FEATURE_ID_LSB - 1;
    //localparam RST_LSB           = RST_MSB - RST_WIDTH + 1;

    localparam CE_MSB            = RST_MSB - 1;
    //localparam CE_LSB            = CE_MSB - CE_WIDTH + 1;

    localparam INP_VALID_MSB     = CE_MSB - 1;
    localparam INP_VALID_LSB     = INP_VALID_MSB - INP_VALID_WIDTH + 1;

    localparam MODE_MSB          = INP_VALID_LSB - 1;
    //localparam MODE_LSB          = MODE_MSB - MODE_WIDTH + 1;

    localparam CMD_MSB           = MODE_MSB - 1;
    localparam CMD_LSB           = CMD_MSB - CMD_WIDTH + 1;

    localparam OPA_MSB           = CMD_LSB - 1;
    localparam OPA_LSB           = OPA_MSB - OPA_WIDTH + 1;

    localparam OPB_MSB           = OPA_LSB - 1;
    localparam OPB_LSB           = OPB_MSB - OPB_WIDTH + 1;

    localparam CIN_MSB           = OPB_LSB - 1;
    //localparam CIN_LSB           = CIN_MSB - CIN_WIDTH + 1;

    localparam EXPECTED_RES_MSB  = CIN_MSB - 1;
    localparam EXPECTED_RES_LSB  = EXPECTED_RES_MSB - EXPECTED_RES_WIDTH + 1;

    localparam COUT_MSB          = EXPECTED_RES_LSB - 1;
    //localparam COUT_LSB          = COUT_MSB - COUT_WIDTH + 1;

    localparam EGL_MSB           = COUT_MSB - 1;
    localparam EGL_LSB           = EGL_MSB - EGL_WIDTH + 1;

    localparam OFLOW_MSB         = EGL_LSB - 1;
    //localparam OFLOW_LSB         = OFLOW_MSB - OFLOW_WIDTH + 1;

    localparam ERR_MSB           = OFLOW_MSB - 1;
    //localparam ERR_LSB           = ERR_MSB - ERR_WIDTH + 1;

    //response packet widths
    localparam RES_START   = 0;
    localparam RES_END     = RES_WIDTH - 1;

    localparam COUT_BIT    = RES_END + 1;

    localparam EGL_START   = COUT_BIT + 1;
    localparam EGL_END     = EGL_START + 2;

    localparam OFLOW_BIT   = EGL_END + 1;
    localparam ERR_BIT     = OFLOW_BIT + 1;

    //Registers and memories
    reg [TOTAL_WIDTH-1:0]         curr_test_case = 0;
    reg [TOTAL_WIDTH-1:0]         stimulus_mem [0:`no_of_testcase-1];
    reg [RES_WIDTH + 6:0]         response_packet;

    event fetch_stimulus;
    integer i, j;

    reg [WIDTH-1:0]   FID;
    reg CLK, RST, MODE, CE, CIN;
    reg [1:0]         INP_VALID;
    reg [3:0]         CMD;
    reg [WIDTH-1:0]   OPA, OPB;
    reg [RES_WIDTH:0] EXPECTED_RES;
    reg [2:0]         EXPECTED_EGL;
    reg EXPECTED_ERR, EXPECTED_COUT, EXPECTED_OFLOW;

    //DUT output wires
    wire ERR, OFLOW, COUT;
    wire [2:0] EGL;
    wire [RES_WIDTH:0] RES;

    //Registers to be compared for verification
    wire [RES_WIDTH + 6:0] expected_data;
    reg [RES_WIDTH + 6:0] exact_data;

    ALU #(WIDTH) dut (
        .CLK(CLK), .RST(RST), .INP_VALID(INP_VALID), .CE(CE),
        .MODE(MODE), .CMD(CMD), .OPA(OPA), .OPB(OPB), .CIN(CIN),
        .ERR(ERR), .RES(RES), .OFLOW(OFLOW), .COUT(COUT),
        .G(EGL[1]), .L(EGL[0]), .E(EGL[2])
    );

    //Read stimulus task
    task read_stimulus();
        begin
            #10 $readmemb("stimulus.txt", stimulus_mem);
        end
    endtask

    //Stimulus fetcher
    integer stim_mem_ptr = 0, stim_stimulus_mem_ptr = 0;
    always@(fetch_stimulus) begin
        curr_test_case = stimulus_mem[stim_mem_ptr];
        $display("stimulus_mem data = %b", curr_test_case);
        stim_mem_ptr = stim_mem_ptr + 1;
    end

    //Clock Generator
    initial begin
        CLK = 0;
        forever #60 CLK = ~CLK;
    end

    //Driver task
    task driver();
        begin
            ->fetch_stimulus;
            @(posedge CLK);
            FID            = curr_test_case[FEATURE_ID_MSB:FEATURE_ID_LSB];
            RST            = curr_test_case[RST_MSB];
            CE             = curr_test_case[CE_MSB];
            INP_VALID      = curr_test_case[INP_VALID_MSB:INP_VALID_LSB];
            MODE           = curr_test_case[MODE_MSB];
            CMD            = curr_test_case[CMD_MSB:CMD_LSB];
            OPA            = curr_test_case[OPA_MSB:OPA_LSB];
            OPB            = curr_test_case[OPB_MSB:OPB_LSB];
            CIN            = curr_test_case[CIN_MSB];
            EXPECTED_RES   = curr_test_case[EXPECTED_RES_MSB:EXPECTED_RES_LSB];
            EXPECTED_COUT  = curr_test_case[COUT_MSB];
            EXPECTED_EGL   = curr_test_case[EGL_MSB:EGL_LSB];
            EXPECTED_OFLOW = curr_test_case[OFLOW_MSB];
            EXPECTED_ERR   = curr_test_case[ERR_MSB];

        $display("\n----------Fetched Testcase & Expected Outputs----------\n");
        $display("At time %0t | Feature_ID=%d OPA=%b OPB=%b INP_VALID=%b CMD=%b CIN=%b CE=%b MODE=%b Expected_RES=%b cout=%b EGL=%b ov=%b err=%b\n",
                 $time, FID, OPA, OPB, INP_VALID, CMD, CIN, CE, MODE, EXPECTED_RES, EXPECTED_COUT, EXPECTED_EGL, EXPECTED_OFLOW, EXPECTED_ERR);
        end
    endtask

    //DUT reset task
    task dut_reset();
        begin
            CE = 1;
            RST = 1;
            #20 RST = 0;
        end
    endtask

    //Global init
    task global_init();
        begin
            curr_test_case = 0;
            response_packet = 0;
            stim_mem_ptr = 0;
            stim_stimulus_mem_ptr = 0;
        end
    endtask

    //Monitor task
    task monitor();
        begin
            @(posedge CLK);
            response_packet[WIDTH-1:0] = curr_test_case;
            response_packet[RES_END:RES_START] = RES;
            response_packet[COUT_BIT] = COUT;
            response_packet[EGL_END:EGL_START] = EGL;
            response_packet[OFLOW_BIT] = OFLOW;
            response_packet[ERR_BIT] = ERR;

            $display("\nMonitor: time %0t | RES=%b COUT=%b EGL=%b OFLOW=%b ERR=%b\n",
                 $time, RES, COUT, EGL, OFLOW, ERR);

            exact_data = {RES, COUT, EGL, OFLOW, ERR};
        end
    endtask

    //Expected data
    assign expected_data = {EXPECTED_RES, EXPECTED_COUT, EXPECTED_EGL, EXPECTED_OFLOW, EXPECTED_ERR};

    //Scoreboard task
    localparam PACKET_WIDTH = 1 + FEATURE_ID_WIDTH + (RES_WIDTH+1+6) + (RES_WIDTH+1+6) + 1 + 1;
    reg [PACKET_WIDTH-1:0] scb_stimulus_mem [0:`no_of_testcase-1];

    task scoreboard();
        reg [RES_WIDTH + 6:0] expected_res_data;
        reg [RES_WIDTH + 6:0] response_data;
        reg [FEATURE_ID_WIDTH-1:0] feature_id;
        begin
            #5;
            feature_id = FID;
            expected_res_data = expected_data;
            response_data = exact_data;

            $display("Scoreboard: Expected = %b, Response = %b\n", expected_res_data, response_data);
            //$display("===========================+End of Testcase============================\n");

            if(expected_data === exact_data)
                scb_stimulus_mem[stim_stimulus_mem_ptr] = {1'b0, feature_id, expected_res_data, response_data, 1'b0, `PASS};
            else
                scb_stimulus_mem[stim_stimulus_mem_ptr] = {1'b0, feature_id, expected_res_data, response_data, 1'b0, `FAIL};
            $display("scb_stimulus_mem : %b\n", scb_stimulus_mem[stim_stimulus_mem_ptr]);
            //move to next
            stim_stimulus_mem_ptr = stim_stimulus_mem_ptr + 1;
            $display("============================End of Testcase============================\n");
        end
    endtask

    //Generate report
    task gen_report();
        integer file_id, pointer;
        reg [PACKET_WIDTH-1:0] status;
        localparam FEATURE_ID_MSB_REPORT = PACKET_WIDTH - 2;
        localparam FEATURE_ID_LSB_REPORT = FEATURE_ID_MSB_REPORT - FEATURE_ID_WIDTH+1;
        begin
            file_id = $fopen("results.txt", "w");
            for(pointer = 0; pointer < `no_of_testcase; pointer = pointer + 1) begin
                status = scb_stimulus_mem[pointer];
                if(status[0]) begin
                    $fdisplay(file_id, "Feature ID %d : PASS", status[FEATURE_ID_MSB_REPORT:FEATURE_ID_LSB_REPORT]);
                end else begin
                    $fdisplay(file_id, "Feature ID %d : FAIL", status[FEATURE_ID_MSB_REPORT:FEATURE_ID_LSB_REPORT]);
                end
            end
        end
    endtask

    //MAIN TESTBENCH BLOCK
    initial begin
        global_init();
        read_stimulus();
        dut_reset();

        for(i = 0; i < `no_of_testcase; i = i + 1) begin
            driver();
            repeat(1)@(posedge CLK);
            monitor();
            scoreboard();
        end

        gen_report();
        $finish;
    end

endmodule
