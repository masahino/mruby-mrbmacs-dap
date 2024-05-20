module Mrbmacs
  # DAP mode
  class DapMode < Mode
    attr_reader :prompt

    SCE_STYLE_DEFAULT = 0
    SCE_STYLE_FILE = 1
    SCE_STYLE_NUMBER = 2
    SCE_STYLE_PROMPT = 5
    # command => [method, description, completion_args, capability]
    DAP_COMMAND_MAP = {
      'launch' => [:dap_launch, 'Launch process', :suggest_file_completion, :suggest_file_completion],
      'attach' => [:dap_attach, 'Attach to process by ID or name.', :suggest_process_completion],
      'break' => [:dap_breakpoint, 'Set breakpoint', nil],
      'delete' => [:dap_delete_breakpoint, '', nil],
      'step' => [:dap_step, '', nil],
      'next' => [:dap_next, '', nil],
      'continue' => [:dap_continue, '', nil],
      'finish' => [:dap_finish, '', nil],
      'run' => [:dap_run, '', nil],
      'p' => [:dap_p, '', nil],
      'configurationDone' => [:dap_run, '', nil],
      'scopes' => [:dap_scopes, '', nil],
      'variables' => [:dap_variables, '', nil],
      'evaluate' => [:dap_evaluate, '', nil],
      'modules' => [nil, '', nil],
      'show' => [:dap_show, '', :suggest_show_completion],
      'terminate' => [:dap_terminate, '', nil],
      'disconnect' => [nil, '', nil],
      'help' => [:dap_help, '', nil]
    }.freeze

    def initialize
      super.initialize
      @name = 'dap'
      @lexer = nil
      @keyword_list = ''
      @style = [
        :color_default,    # 0: default
        :color_function_name, # 1: file path
        :color_keyword,       # 2: number
        :color_warning,       # 3: pattern
        :color_string,        # 4: reserve
        :color_comment        # 5: reserve
      ]
      @keymap['Enter'] = 'dap_exec_command'
      @keymap['Tab'] = 'dap_completion'
      @keymap['C-g'] = 'dap_pause'
      @prompt = '(dap) '
    end

    def set_style(view_win, theme)
      super
      view_win.sci_set_property('fold.compact', '1')
    end

    def is_end_of_block(_line)
      false
    end

    def set_lexer(view_win) end

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
          app.frame.view_win.sci_set_styling(Regexp.last_match[1].length, SCE_STYLE_PROMPT) # prompt
          app.frame.view_win.sci_set_styling(Regexp.last_match[2].length, SCE_STYLE_DEFAULT) # normal text
        else
          app.frame.view_win.sci_set_styling(line_length, SCE_STYLE_DEFAULT)
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
      @frame.view_win.sci_autoc_show(input_length, candidates) unless candidates.nil? || candidates.size.zero?
    end

    def dap_exec_command
      if @frame.view_win.sci_autoc_active
        @frame.view_win.sci_autoc_complete
        return
      end

      line_str = @frame.view_win.sci_get_curline[0].delete_prefix(@current_buffer.mode.prompt)
      command = line_str.split(/\s+/)
      @frame.view_win.sci_newline

      if command[0].nil? && !@dap_last_command.nil?
        command = @dap_last_command
      end
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
