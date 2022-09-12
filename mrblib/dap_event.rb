module Mrbmacs
  class Application
    def dap_event_stopped(body)
      dap_output "[Stopped] reason:#{body['reason']}, ThreadId = #{body['threadId']} #{body['description']}"
      # dap_output JSON.pretty_generate body
      @dap_thread_id = body['threadId'].to_i
      @dap_client.stackTrace({ 'threadId' => @dap_thread_id, 'levels' => 1 }) do |res|
        if res['success']
          stackframe = res['body']['stackFrames'][0]
          @dap_frame_id = stackframe['id']
          dap_show_current_pos(stackframe['source']['path'], stackframe['line'] - 1)
          dap_output_stacktrace(res['body'])
        end
      end
    end

    def dap_process_event(event, body)
      #      dap_output "\n" # [event] #{event}"
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
        dap_output "[Output] #{body['category']}: \n#{body['output']}"
      when 'continued'
        dap_output "[Continued] threadId = #{body['threadId']}"
      when 'exited'
        dap_output "[Exited] exit code = #{body['exitCode']}"
      when 'terminated'
        dap_output '[Terminated]'
        dap_stop_adapter
      else
        dap_output "[#{event}]"
        dap_output JSON.pretty_generate(body) unless body.nil?
      end
      dap_prompt
    end
  end
end
