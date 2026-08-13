module Mrbmacs
  class DapTestLogger
    attr_reader :messages

    def initialize
      @messages = []
    end

    def info(message)
      @messages << message
    end
  end

  class DapTestClient
    attr_accessor :adapter_capabilities, :message, :stack_trace_response
    attr_reader :calls, :source_breakpoints

    def initialize
      @adapter_capabilities = {}
      @calls = []
      @source_breakpoints = {}
    end

    def launch(arguments)
      @calls << [:launch, arguments]
    end

    def restart(arguments)
      @calls << [:restart, arguments]
    end

    def configurationDone
      @calls << [:configurationDone]
    end

    def initialized
      @calls << [:initialized]
    end

    def update_adapter_capabilities(capabilities)
      @calls << [:update_adapter_capabilities, capabilities]
      @adapter_capabilities.merge!(capabilities)
    end

    def stackTrace(arguments)
      @calls << [:stackTrace, arguments]
      yield @stack_trace_response
    end

    def wait_message
      @message
    end
  end

  class DapTestApplication < Application
    attr_reader :outputs, :prompt_count, :stop_count, :shown_position
    attr_accessor :dap_last_event

    def initialize
      @outputs = []
      @prompt_count = 0
      @stop_count = 0
      @logger = DapTestLogger.new
    end

    def logger
      @logger
    end

    def dap_output(message)
      @outputs << message
    end

    def dap_prompt
      @prompt_count += 1
    end

    def dap_stop_adapter
      @stop_count += 1
    end

    def dap_show_current_pos(path, line)
      @shown_position = [path, line]
    end
  end
end

def setup_dap_test_application
  app = Mrbmacs::DapTestApplication.new
  client = Mrbmacs::DapTestClient.new
  app.dap_client = client
  [app, client]
end
