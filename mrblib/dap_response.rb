module Mrbmacs
  # DAP response
  class Application
    def dap_output_stacktrace(body)
      indent = ''
      body['stackFrames'].each_with_index do |sf, i|
        if i == 0
          indent = '*'
        else
          indent = ' '
        end
        dap_output "#{indent}frameId = #{sf['id']}: #{sf['name']} #{sf['source']['path']}:#{sf['line']}"
      end
    end

    def dap_output_variables_response(message)
      return if message['body'].nil?

      message['body']['variables'].each do |v|
        dap_output "#{v['name']} = #{v['value']} (#{v['type']})"
      end
    end

    def dap_output_breakpoints_response(message)
      dap_mark_all_breakpoints
      bps = message['body']['breakpoints']
      bps.each do |bp|
        if bp.key?('id') && bp.key?('source') && bp.key?('line')
          dap_output("[Breakpoints] #{bp['id']}: #{bp['source']['path']}:#{bp['line']}")
        end
      end
    end

    def dap_output_response(message)
      case message['command']
      when 'setBreakpoints', 'setFunctionBreakpoints'
        dap_output_breakponits_response(message)
      when 'variables'
        dap_output_variables_response(message)
      when 'continue'
        # none
      else
        dap_output(message['body']) unless message['body'].nil?
      end
    end

    def dap_process_response(message)
      # dap_output JSON.pretty_generate message
      if message['success']
        dap_output '[response] success'
        dap_output_response(message)
      else
        dap_output '[response] fail'
        dap_output message
      end
      dap_prompt
    end
  end
end
