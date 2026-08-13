module Mrbmacs
  # DAP event
  class Application
    def dap_event_stopped(body)
      # dap_output "[Stopped] reason:#{body['reason']}, ThreadId = #{body['threadId']} #{body['description']}"
      # dap_output JSON.pretty_generate body
      @dap_thread_id = body['threadId'].to_i
      @dap_client.stackTrace({ 'threadId' => @dap_thread_id, 'levels' => 1 }) do |res|
        @logger.info JSON.generate(res)

        if res['success']
          stackframe = res['body']['stackFrames'][0]
          @dap_frame_id = stackframe['id']
          dap_show_current_pos(stackframe['source']['path'], stackframe['line'] - 1)
          dap_output_stacktrace(res['body'])
        end
      end
    end

    def dap_event_breakpoint(body)
      breakpoint = body['breakpoint']
      location = breakpoint.dig('source', 'path')

      if location.nil?
        location = breakpoint['instructionReference']
      end

      location = "breakpoint #{breakpoint['id']}" if location.nil?
      location += ":#{breakpoint['line']}" unless breakpoint['line'].nil?
      location += ":#{breakpoint['column']}" unless breakpoint['column'].nil?

      dap_output "[Breakponit] #{body['reason']}: #{location}"
    end

    def dap_process_event(event, body)
      @dap_last_event = event
      case event
      when 'stopped'
        dap_event_stopped(body)
      when 'process'
        dap_output "[Process] #{body['systemProcessId']} launched: #{body['name']}"
      when 'initialized'
        #      @client.threads do |res|
        #        @thread_id = res['body']['threads'][0]['id'] if res['body']['threads'].size > 0
        #      end
        @dap_client.initialized
      when 'output'
        # dap_output "[Output] #{body['category']}: \n#{body['output']}"
        dap_output "[Output] #{body['category']}: #{body['output']}"
      when 'continued'
        @logger.info "[Continued] threadId = #{body['threadId']}"
      when 'exited'
        dap_output "[Exited] exit code = #{body['exitCode']}"
      when 'terminated'
        dap_output '[Terminated]'
        # dap_stop_adapter
      when 'breakpoint'
        dap_event_breakpoint(body)
      when 'capabilities'
        @dap_client.update_adapter_capabilities(body['capabilities'])
      else
        # dap_output "[#{event}]"
        # dap_output JSON.pretty_generate(body) unless body.nil?
        @logger.info "[#{event}]"
        @logger.info JSON.pretty_generate(body) unless body.nil?
      end
      dap_prompt
    end
  end
end
