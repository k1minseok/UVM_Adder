`timescale 1ns / 1ps

`include "uvm_macros.svh"
`include "E:\Verilog\Vivado\2023.2\data\system_verilog\uvm_1.2\xlnx_uvm_package.sv"
import uvm_pkg::*;


interface adder_interface;
    logic [31:0] a;
    logic [31:0] b;

    logic [31:0] result;
endinterface


// transaction
class seq_item extends uvm_sequence_item;   // uvm에 이미 정의되어 있는 클래스의 상속
    rand bit [31:0] a;
    rand bit [31:0] b;
    bit      [31:0] result;

    constraint adder_c {
        a < 100;
        b < 100;
    }
    ;

    // 보통 클래스 이름을 넣어줌
    function new(input string name = "seq_item");
        super.new(name);
        // super. => 부모(슈퍼) 클래스 의미, super class instance 생성
    endfunction

    `uvm_object_utils_begin(seq_item)  // UVM 팩토리에 클래스 등록 시작
        `uvm_field_int(a, UVM_DEFAULT)  // 필드 값(a,b), UVM_DEFAULT : 필드 기본 동작 지정 플래그
        `uvm_field_int(b, UVM_DEFAULT)  // 필드 값(a,b)
        `uvm_field_int(result, UVM_DEFAULT)  // 필드 값(a,b)
    `uvm_object_utils_end

endclass


// generator
class adder_sequence extends uvm_sequence;
// uvm_sequence 클래스는 기본적으로 uvm_sequence_item 타입을 처리하도록 설계되어 있어
// 트랜잭션 타입을 지정하지 않아도 됨.
    `uvm_object_utils(adder_sequence)
    // UVM 팩토리에 클래스를 등록

    seq_item adder_seq_item;  // Handler

    function new(input string name = "adder_sequence");
        super.new(name);
    endfunction

    virtual task body();    // virtual : 다형성 기능, 슈퍼 클래스의 body task를 재정의
        adder_seq_item =
            seq_item::type_id::create("SEQ_ITEM");  // create instance
        // seq_item 안의 type_id 안의 create 실행(인스턴스 이름을 SEQ_ITEM으로)
        repeat (1000) begin
            start_item(adder_seq_item);
            adder_seq_item.randomize();  // sequence 랜덤 변수 생성
            `uvm_info("SEQ", "Data send to Driver", UVM_NONE);
            // UVM_NONE : 메시지 중요도, 메시지의 중요도에 따라 출력할지 안할지 코딩할 수 있음.
            finish_item(adder_seq_item);
        end
    endtask

endclass


class adder_driver extends uvm_driver #(seq_item);
// #(seq_item) : 제네릭 클래스인 uvm_driver의 트랜잭션 타입을 파라미터로 입력해줌
// driver는 트랜잭션을 직접 dut에 입력하기에 트랜잭션 타입이 명확해야한다.
    `uvm_component_utils(adder_driver)  // UVM 팩토리에 클래스 등록
    // object : 데이터 모델링, component : 시뮬레이션 환경 구성

    virtual adder_interface adder_Intf;
    seq_item adder_seq_item;  // Handler

    function new(input string name = "adder_driver", uvm_component c);
        super.new(name, c);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        // virtual function : 이 class의 subclass에서 이 함수를 재정의 할 수 있도록 한다.
        // 유연성, 확장성 증가
        super.build_phase(phase);
        adder_seq_item = seq_item::type_id::create("SEQ_ITEM", this);
        // 인스턴스 생성, 객체 동적 생성
        if (!uvm_config_db#(virtual adder_interface)::get(
                this, "", "adderIntf", adder_Intf
            )) begin
            `uvm_fatal(get_name(), "Unable to access adder interface");
            // 에러 발생했을 때 메시지를 출력하고 시뮬레이션 종료
            // interface 정보를 db에서 가져온다. -> db를 통해 interface 핸들러 설정
        end
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
        $display("display start of simulation phase!");
    endfunction

    virtual task run_phase(uvm_phase phase);
        $display("display run phase!");
        forever begin
            #10;
            seq_item_port.get_next_item(adder_seq_item);
            adder_Intf.a = adder_seq_item.a;     // 시퀀스의 값을 interface로 보냄
            adder_Intf.b = adder_seq_item.b;
            `uvm_info("DRV", "Send data to DUT", UVM_NONE);
            seq_item_port.item_done();
        end
    endtask

endclass


class adder_monitor extends uvm_monitor;
    `uvm_component_utils(adder_monitor);

    uvm_analysis_port #(seq_item) send; // 다른 컴포넌트와 연결하는 출력 포트
    virtual adder_interface adderIntf;
    seq_item adder_seq_item;

    function new(input string name = "adder_monitor", uvm_component c);
        super.new(name, c);
        send = new("WRITE", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        adder_seq_item = seq_item::type_id::create("SEQ_ITEM", this);
        if (!uvm_config_db#(virtual adder_interface)::get(
                this, "", "adderIntf", adderIntf
            )) begin
            `uvm_fatal(get_name(), "Unable to access adder interface");
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            #10;
            adder_seq_item.a = adderIntf.a;
            adder_seq_item.b = adderIntf.b;
            adder_seq_item.result = adderIntf.result;
            `uvm_info("MON", "send data to Scoreboard", UVM_NONE);
            send.write(adder_seq_item);
            // send 포트를 통해 adder_seq_item 트랜잭션 전송
        end
    endtask

endclass


class adder_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(adder_scoreboard);

    uvm_analysis_imp #(seq_item, adder_scoreboard) recv; // 다른 컴포넌트와 연결하는 입력 포트

    function new(input string name = "adder_scoreboard", uvm_component c);
        super.new(name, c);
        recv = new("READ", this);
    endfunction


    // recv 포트로 데이터가 들어오면 자동으로 write 함수가 콜백됨
    virtual function void write(seq_item data);
        `uvm_info("SCB", "Data received from Monitor", UVM_NONE);

        if ((data.a + data.b) == data.result) begin
            `uvm_info("SCB", $sformatf("PASS!, %d + %d = %d", data.a, data.b,
                                       data.result), UVM_NONE);
        end else begin
            `uvm_error("SCB", $sformatf("FAIL!, %d + %d = %d", data.a, data.b,
                                        data.result));
        end
        data.print(uvm_default_line_printer);
    endfunction

endclass


class adder_agent extends uvm_agent;
    `uvm_component_utils(adder_agent)

    function new(input string name = "adder_agent", uvm_component c);
        super.new(name, c);
    endfunction

    adder_monitor adderMonitor;  // Handler
    adder_driver adderDriver;
    uvm_sequencer #(seq_item) adderSequencer;  // UVM 내장 시퀀서 사용

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        adderMonitor = adder_monitor::type_id::create("MON", this);
        adderDriver = adder_driver::type_id::create("DRV", this);
        adderSequencer = uvm_sequencer#(seq_item)::type_id::create("SQR", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        adderDriver.seq_item_port.connect(adderSequencer.seq_item_export);
        // 드라이버와 시퀀서 연결
    endfunction

endclass


class adder_env extends uvm_env;
    `uvm_component_utils(adder_env)

    function new(input string name = "adder_env", uvm_component c);
        super.new(name, c);
    endfunction

    adder_scoreboard adderScoreboard;
    adder_agent adderAgent;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        adderScoreboard = adder_scoreboard::type_id::create("SCB", this);
        adderAgent = adder_agent::type_id::create("AGENT", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        adderAgent.adderMonitor.send.connect(adderScoreboard.recv);
        // 모니터의 send와 스코어보드의 receive 연결
    endfunction

endclass


class adder_test extends uvm_test;
    `uvm_component_utils(adder_test)

    function new(input string name = "adder_test", uvm_component c);
        super.new(name, c);
    endfunction

    adder_sequence adderSequence;
    adder_env adderEnv;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        adderSequence = adder_sequence::type_id::create("SEQ", this);
        adderEnv = adder_env::type_id::create("ENV", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);    // 시뮬레이션이 완료될때까지 페이즈 유지
        adderSequence.start(adderEnv.adderAgent.adderSequencer);
        // 시퀀스를 시퀀서를 통해 동작하도록 함.
        phase.drop_objection(this);     // 시뮬레이션 완료되면 페이즈 종료
    endtask

endclass


module tb_Adder ();

    adder_interface adderIntf ();
    adder_test adderTest;

    adder dut (
        .a(adderIntf.a),
        .b(adderIntf.b),

        .result(adderIntf.result)
    );

    initial begin
        adderTest = new("Adder UVM Verification", null);
        uvm_config_db#(virtual adder_interface)::set(null, "*", "adderIntf",
                                                     adderIntf);
        // 실체화된 interface 정보를 db에 저장
        // 시스템베릴로그에서는 생성자에서 인터페이스 정보를 넘겨줬다면
        // 여기에서는 db를 통해 넘겨줌
        run_test();
    end

endmodule
