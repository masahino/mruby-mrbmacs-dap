module Mrbmacs
  class Application
    attr_accessor :dap_client

    def dap_completion
      input_text = ''
    end

    def dap_mark_breakpoints(filename)
      return if @dap_client.nil?

      unless @dap_client.source_breakpoints[filename].nil?
        @dap_client.source_breakpoints[filename].each do |line|
          @frame.view_win.sci_marker_add(line, Mrbmacs::MARKERN_BREAKPOINT)
        end
      end
    end

    def dap_switch_buffer(buffer_name)
      return if @current_buffer.name == buffer_name

      tmp_win = @frame.edit_win_from_buffer(buffer_name)
      unless tmp_win.nil?
        @frame.switch_window(tmp_win)
        @current_buffer = @frame.edit_win.buffer
        return
      end
      split_window_vertically if @frame.edit_win_list.size == 1
      other_window
      @frame.refresh_all

      result_buffer = Mrbmacs.get_buffer_from_name(@buffer_list, buffer_name)
      if result_buffer.nil?
        result_buffer = Mrbmacs::Buffer.new(buffer_name)
        add_new_buffer(result_buffer)
        add_buffer_to_frame(result_buffer)
        set_buffer_mode(result_buffer)
        #       @frame.set_theme(@theme)
        @frame.set_buffer_name(buffer_name)
      end
      switch_to_buffer(buffer_name)
    end

    def dap_output(message)
      dap_switch_buffer(DAPExtension::DAP_BUFFER_NAME)
      @current_buffer.docpointer = @frame.view_win.sci_get_docpointer
      message = JSON.pretty_generate(message) if message.is_a? Hash
      @frame.view_win.sci_del_line_left
      @frame.view_win.sci_insert_text(@frame.view_win.sci_get_length, message + "\n")
      @frame.view_win.sci_goto_pos(@frame.view_win.sci_get_length)
    end

    def dap_prompt
      dap_switch_buffer(DAPExtension::DAP_BUFFER_NAME)
      @current_buffer.docpointer = @frame.view_win.sci_get_docpointer
      @frame.view_win.sci_del_line_left
      @frame.view_win.sci_insert_text(@frame.view_win.sci_get_length, @current_buffer.mode.prompt)
      @frame.view_win.sci_goto_pos(@frame.view_win.sci_get_length)
      @current_buffer.additional_info = "#{@dap_lang}:#{@dap_last_event}"
    end

    def dap_output_stacktrace(body)
      indent = ''
      body['stackFrames'].each_with_index do |sf, i|
        if i == 0
          indent = '*'
        else
          indent = ' '*(i+1)
        end
        dap_output "#{indent}frameId = #{sf['id']}: #{sf['name']} #{sf['source']['path']}:#{sf['line']}"
      end
    end

    def dap_output_response(message)
      case message['command']
      when 'setBreakpoints', 'setFunctionBreakpoints'
        bps = message['body']['breakpoints']
        bps.each do |bp|
          if bp.key?('id') && bp.key?('source') && bp.key?('line')
            dap_output("[Breakpoints] #{bp['id']}: #{bp['source']['path']}:#{bp['line']}")
          end
        end
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

    def dap_read_message(_io)
$stderr.puts 'dap_read_message start'
      message = @dap_client.wait_message
$stderr.puts 'dap_read_message recieved'
      return if message.nil?

$stderr.puts 'dap_read_message x'
      case message['type']
      when 'response'
        dap_process_response(message)
      when 'event'
$stderr.puts 'dap_read_message event'
        dap_process_event(message['event'], message['body'])
      else
        $stderr.puts @dap_client.io.eof?

        dap_output "unknown message [#{message['type']}]"
      end
$stderr.puts 'dap_read_message end'
    end

    def dap_show_current_pos(path, line)
      return if path.nil?

      @frame.edit_win_list.each do |win|
        win.sci.sci_marker_delete_all(Mrbmacs::MARKERN_CURRENT)
      end
      split_window if @frame.edit_win_list.size == 1
      other_window
      find_file(path)
      pos = @frame.view_win.sci_position_from_line(line)
      @frame.view_win.sci_goto_pos(pos)
      @frame.view_win.sci_marker_add(line, Mrbmacs::MARKERN_CURRENT)
      recenter
    end

    def dap_toggle_breakpoint(position = nil)
      lang = @current_buffer.mode.name
      position = @frame.view_win.sci_get_current_pos if position.nil?
      line = @frame.view_win.sci_line_from_position(position)
      if ((@frame.view_win.sci_marker_get(line) >> Mrbmacs::MARKERN_BREAKPOINT) & 0x01) == 1
        @frame.view_win.sci_marker_delete(line, Mrbmacs::MARKERN_BREAKPOINT)
        @config.ext['dap'].each do |dap_lang, value|
          if value[:langs].include? lang
            @ext.data['dap'][dap_lang].delete_breakpoint(@current_buffer.filename, line + 1)
          end
        end
      else
        @frame.view_win.sci_marker_add(line, Mrbmacs::MARKERN_BREAKPOINT)
        @config.ext['dap'].each do |dap_lang, value|
          @ext.data['dap'][dap_lang].add_breakpoint(@current_buffer.filename, line + 1) if value[:langs].include? lang
        end
      end
    end

    def dap_select_lang
      lang = @current_buffer.mode.name
      lang_list = @config.ext['dap'].keys
      lang = '' unless lang_list.include? lang
      @frame.echo_gets('debugger type: ', lang) do |input_text|
        [lang_list.join(' '), input_text.length]
      end
    end

    def dap_get_target(type)
      if @config.ext['dap'][type][:require_target]
        read_file_name('target :', @current_buffer.directory, @current_buffer.basename)
      else
        ''
      end
    end

    def dap_stop_adapter
      del_io_read_event(@dap_client.io)
      @dap_client.stop_adapter unless @dap_client.nil?
    end

    def dap(lang = nil)
      lang = dap_select_lang if lang.nil?
      if @config.ext['dap'][lang].nil?
        message 'unkonwn debugger type'
        return
      end

      @dap_lang = lang
      target = dap_get_target(@dap_lang)
      dap_config = @config.ext['dap'][@dap_lang]
      @dap_client = @ext.data['dap'][@dap_lang]
      @dap_client.add_adapter_args(target) if target != ''
      @dap_last_event = ''
      @dap_breakpoints = {}
      # dap_switch_buffer(DAPExtension::DAP_BUFFER_NAME)
      # @current_buffer.docpointer = @frame.view_win.sci_get_docpointer
      @dap_client.start_debug_adapter({ 'adapterID' => dap_config[:type] })
      unless @dap_client.io.nil?
        dap_prompt
        add_io_read_event(@dap_client.io) do |app, io|
          app.dap_read_message(io)
        end
      end
    end
  end
end