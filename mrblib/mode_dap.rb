module Mrbmacs
  # DAP mode
  class DapMode < Mode
    attr_reader :prompt

    include Scintilla

    SCE_STYLE_DEFAULT = 0
    SCE_STYLE_FILE = 1
    SCE_STYLE_NUMBER = 2
    SCE_STYLE_PROMPT = 5
    DAP_COMMAND_MAP = {
      'launch' => :dap_launch,
      'attach' => :dap_attach,
      'break' => :dap_breakpoint,
      'delete' => :dap_delete_breakpoint,
      'step' => :dap_step,
      'next' => :dap_next,
      'continue' => :dap_continue,
      'finish' => :dap_finish,
      'run' => :dap_run,
      'p' => :dap_p,
      'configurationDone' => :dap_run,
      'scopes' => :dap_scopes,
      'variables' => :dap_variables,
      'evaluate' => :dap_evaluate,
      'show' => :dap_show
    }.freeze

    def initialize
      super.initialize
      @name = 'dap'
      @lexer = nil
      @keyword_list = ''
      @style = [
        :color_foreground,    # 0: default
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

    def self.dap_method(input)
      return DAP_COMMAND_MAP[input] if DAP_COMMAND_MAP.key?(input)

      DAP_COMMAND_MAP.each_key do |command|
        return DAP_COMMAND_MAP[command] if command.start_with?(input)
      end
      nil
    end
  end

  class Application
    def dap_completion
      lines = @frame.view_win.sci_get_curline[0].delete_prefix(@current_buffer.mode.prompt).split(/\s+/)
      case lines.size
      when 0
        @frame.view_win.sci_autoc_show(0, DapMode::DAP_COMMAND_MAP.keys.join(' '))
      when 1
        @frame.view_win.sci_autoc_show(lines[0].length,
                                       DapMode::DAP_COMMAND_MAP.keys.filter { |c| c.start_with? lines[0] }.join(' '))
      when 2
        $stderr.puts lines[1]
      end
    end

    def dap_exec_command
      line_str = @frame.view_win.sci_get_curline[0].delete_prefix(@current_buffer.mode.prompt)
      command = line_str.split(/\s+/)
      @frame.view_win.sci_newline

      if command[0].nil? && !@dap_last_command.nil?
        command = @dap_last_command
      end
      unless command[0].nil? || @dap_client.nil?
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
