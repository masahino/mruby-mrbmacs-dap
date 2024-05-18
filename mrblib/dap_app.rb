module Mrbmacs
  # DAP command
  module Command
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
      @dap_last_command = nil
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

  # DAP
  class Application
    attr_accessor :dap_client

    def dap_completion
      input_text = ''
    end

    def dap_mark_breakpoints(filename)
      return if @dap_client.nil?
      return if @dap_client.source_breakpoints[filename].nil?

      @frame.edit_win_list.each do |win|
        next if win.buffer.filename != filename

        @dap_client.source_breakpoints[filename].each do |line|
          add_breakpoint_marker(win.sci, line - 1) unless breakpoint_marker_exists?(win.sci, line - 1)
        end
        win.refresh
      end
    end

    def dap_mark_all_breakpoints
      @dap_client.source_breakpoints.each_key do |filename|
        dap_mark_breakpoints(filename)
      end
    end

    def dap_switch_buffer(buffer_name)
      return if @current_buffer.name == buffer_name

      setup_result_buffer(buffer_name)
    end

    def dap_output(message)
      dap_switch_buffer(DAPExtension::DAP_BUFFER_NAME)
      @current_buffer.docpointer = @frame.view_win.sci_get_docpointer
      message = JSON.pretty_generate(message) if message.is_a? Hash
      @frame.view_win.sci_del_line_left
      @frame.view_win.sci_insert_text(@frame.view_win.sci_get_length, "#{message}\n")
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

    def dap_read_message(_io)
      message = @dap_client.wait_message
      return if message.nil?

      dap_output Time.now.to_s
      case message['type']
      when 'response'
        dap_process_response(message)
      when 'event'
        dap_process_event(message['event'], message['body'])
      else
        dap_output "unknown message [#{message['type']}]"
      end
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
      if breakpoint_marker_exists?(@frame.view_win, line)
        remove_breakpoint_marker(@frame.view_win, line)
        update_dap_clients(:delete_breakpoint, @current_buffer.filename, line + 1, lang)
      else
        add_breakpoint_marker(@frame.view_win, line)
        update_dap_clients(:add_breakpoint, @current_buffer.filename, line + 1, lang)
      end
    end

    def dap_select_lang
      lang = @current_buffer.mode.name
      lang_list = @config.ext['dap'].keys
      lang = '' unless lang_list.include? lang
      @frame.echo_gets('debugger type: ', lang) do |input_text|
        [lang_list.join(@frame.echo_win.sci_autoc_get_separator.chr), input_text.length]
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
      @dap_client = nil
    end

    def breakpoint_marker_exists?(win, line)
      ((win.sci_marker_get(line) >> Mrbmacs::MARKERN_BREAKPOINT) & 0x01) == 1
    end

    def add_breakpoint_marker(win, line)
      win.sci_marker_add(line, Mrbmacs::MARKERN_BREAKPOINT)
    end

    def remove_breakpoint_marker(win, line)
      win.sci_marker_delete(line, Mrbmacs::MARKERN_BREAKPOINT)
    end

    def update_dap_clients(action, filename, line, lang)
      @config.ext['dap'].each do |dap_lang, value|
        if value[:langs].include? lang
          @ext.data['dap'][dap_lang].send(action, filename, line)
        end
      end
    end
  end
end
