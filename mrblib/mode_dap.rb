module Mrbmacs
  # DAP mode
  class DapMode < Mode
    attr_reader :prompt

    # command => [method, description, completion_args, capability]
    DAP_COMMAND_MAP = {
      'launch' => [:dap_launch, 'Launch a program', :suggest_file_completion, :suggest_file_completion],
      'attach' => [:dap_attach, 'Attach to a process by ID or name.', :suggest_process_completion],
      'break' => [:dap_breakpoint, 'Set a source or function breakpoint', nil],
      'delete' => [:dap_delete_breakpoint, 'Delete all breakpoints', nil],
      'continue' => [:dap_continue, 'Continue execution', nil],
      'step' => [:dap_step, 'Step into', nil],
      'next' => [:dap_next, 'Step over', nil],
      'finish' => [:dap_finish, 'Step out', nil],
      'run' => [:dap_run, 'Complete configuration and run', nil],
      'p' => [:dap_p, 'Print a variable', nil],
      'configurationDone' => [:dap_run, 'Complete configuration and run', nil],
      'scopes' => [:dap_scopes, 'Show scopes', nil],
      'variables' => [:dap_variables, 'Show variables by reference', nil],
      'evaluate' => [:dap_evaluate, 'Evaluate an expression', nil],
      'modules' => [:dap_modules, 'Show modules', nil],
      'show' => [:dap_show, 'Show DAP information', :suggest_show_completion],
      'terminate' => [:dap_terminate, 'Terminate the debuggee', nil],
      'disconnect' => [:dap_disconnect, 'Disconnect the debug adapter', nil],
      'restart' => [:dap_restart, 'Restart the current debug session', nil],
      'help' => [:dap_help, 'Show command help', nil]
    }.freeze

    def initialize
      super
      @name = 'dap'
      @lexer_profile = DAP_LEXER_PROFILE
      @keymap['Enter'] = 'dap_exec_command'
      @keymap['Tab'] = 'dap_completion'
      @keymap['C-a'] = 'dap_beginning_of_line'
      @keymap['C-g'] = 'dap_pause'
      @prompt = '(dap) '
    end

    def is_end_of_block(_line)
      false
    end

    def on_style_needed(app, scn)
      start_line = app.frame.view_win.sci_line_from_position(app.frame.view_win.sci_get_end_styled)

      end_pos = scn['position']
      end_line = app.frame.view_win.sci_line_from_position(end_pos)
      for i in start_line..end_line
        pos = app.frame.view_win.sci_position_from_line(i)
        line_length = app.frame.view_win.sci_line_length(i)
        next if line_length == 0

        app.frame.view_win.sci_start_styling(pos, 0)
        line = app.frame.view_win.sci_get_line(i)
        if line =~ /^(#{Regexp.escape(@prompt)})(.*)$/
          app.frame.view_win.sci_set_styling(Regexp.last_match[1].length, DAP_STYLE_PROMPT) # prompt
          app.frame.view_win.sci_set_styling(Regexp.last_match[2].length, DAP_STYLE_DEFAULT) # normal text
        else
          app.frame.view_win.sci_set_styling(line_length, DAP_STYLE_DEFAULT)
        end
      end
    end

    def self.command_info(input, n)
      return DAP_COMMAND_MAP[input][n] if DAP_COMMAND_MAP.key?(input)

      DAP_COMMAND_MAP.each_key do |command|
        return DAP_COMMAND_MAP[command][n] if command.start_with?(input)
      end
      nil
    end

    def self.dap_method(input)
      DapMode.command_info(input, 0)
    end

    def self.candidates_arg(input)
      completion_method = command_info(input[0], input.size)
      return if completion_method.nil?

      send(completion_method, input[-1])
    end
  end

  # Application
  class Application
    def dap_completion
      lines = @frame.view_win.sci_get_curline[0].delete_prefix(@current_buffer.mode.prompt).split(/\s+/, -1)
      separator = @frame.view_win.sci_autoc_get_separator.chr
      case lines.size
      when 0
        input_length = 0
        candidates = DapMode::DAP_COMMAND_MAP.keys.join(separator)
      when 1
        input_length = lines[0].length
        candidates = DapMode::DAP_COMMAND_MAP.keys.filter { |c| c.start_with? lines[0] }.join(separator)
      when 2, 3
        input_length = lines[-1].length
        candidates = DapMode.candidates_arg(lines)
        candidates = candidates.join(separator) unless candidates.nil?
      end
      @frame.view_win.sci_autoc_show(input_length, candidates) unless candidates.nil? || candidates.empty?
    end

    def dap_exec_command
      if @frame.view_win.sci_autoc_active
        @frame.view_win.sci_autoc_complete
        return
      end

      line_str = @frame.view_win.sci_get_curline[0].delete_prefix(@current_buffer.mode.prompt)
      command = line_str.split(/\s+/)
      @frame.view_win.sci_newline

      command = @dap_last_command if command[0].nil? && !@dap_last_command.nil?
      unless command[0].nil? # || @dap_client.nil?
        dap_method = DapMode.dap_method(command[0])
        if !dap_method.nil?
          send(dap_method, command[1..])
        elsif @dap_client.respond_to?(command[0])
          @dap_client.send('send_request', command[0])
        else
          dap_output 'unknown command'
        end
      end
      @dap_last_command = command
      dap_prompt
    end
  end
end
