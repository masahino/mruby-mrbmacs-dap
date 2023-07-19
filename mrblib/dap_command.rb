module Mrbmacs
  # Dap commands
  class Application
    def dap_launch(args = [])
      program = args[0]
      program_args = args[1..]
      if program.nil?
        inputs = read_file_name('program: ', @current_buffer.directory).split(/\s+/)
        program = inputs[0]
        program_args = inputs[1..] unless inputs[1].nil?
      end
      @dap_client.launch({ 'program' => program, 'args' => program_args })
    end

    def dap_attach(args = [])
      process = args[0]
      return if process.nil?

      args = {}
      if process.to_i != 0
        args['pid'] = process.to_i
      else
        args['program'] = process
      end
      @dap_client.attach(args)
    end

    def dap_run(_args = [])
      @dap_client.configurationDone
    end

    def dap_command(command)
      @frame.edit_win_list.each do |win|
        win.sci.sci_marker_delete_all(Mrbmacs::MARKERN_CURRENT)
        win.refresh
      end
      @dap_client.send_request(command, { 'threadId' => @dap_thread_id })
    end

    def dap_step(_args = [])
      dap_command('stepIn')
    end

    def dap_next(_args = [])
      dap_command('next')
    end

    def dap_continue(_args = [])
      dap_command('continue')
    end

    def dap_pause(_args = [])
      if @frame.view_win.sci_autoc_active
        @frame.view_win.sci_autoc_cancel
      else
        dap_command('pause')
      end
    end

    def dap_finish(_args = [])
      dap_command('stepOut')
    end

    def dap_breakpoint(args = [])
      return if args == []

      bp_str = args[0]
      if bp_str.index(':').nil?
        bp = DAP::Type::FunctionBreakpoint.new(bp_str)
        @dap_client.setFunctionBreakpoints({ 'breakpoints' => [bp] })
      else
        source = DAP::Type::Source.new(bp_str.split(':')[0])
        line = bp_str.split(':')[1].to_i
        @dap_client.add_breakpoint(source.path, line)
        #        bp = DAP::Type::SourceBreakpoint.new(bp_str.split(':')[1].to_i)
        #        @dap_client.setBreakpoints({ 'source' => source, 'breakpoints' => [bp] })
      end
    end

    def dap_delete_breakpoint(_args = [])
      @frame.edit_win_list.each do |win|
        win.sci.sci_marker_delete_all(Mrbmacs::MARKERN_BREAKPOINT)
      end
      @frame.refresh_all
      @dap_client.setFunctionBreakpoints({ 'breakpoints' => [] })
      @dap_client.delete_all_source_breakpoints
    end

    def dap_scopes(_args = [])
      @dap_client.scopes({ 'frameId' => @dap_frame_id }) unless @dap_frame_id.nil?
    end

    def dap_evaluate(args = [])
      return if args == []

      expression = args.join(' ')
      @dap_client.evaluate({ 'expression' => expression, 'frameId' => @dap_frame_id })
    end

    def dap_variables(args = [])
      return if args == []

      @dap_client.variables({ 'variablesReference' => args[0].to_i })
    end

    def dap_p(args = [])
      return if args == [] || @dap_frame_id.nil?

      @dap_client.scopes({ 'frameId' => @dap_frame_id }) do |scopes_res|
        break if scopes_res['success'] == false

        scopes_res['body']['scopes'].each do |scope|
          @dap_client.variables({ 'variablesReference' => scope['variablesReference'] }) do |vars_res|
            break if vars_res['sucess'] == false

            vars_res['body']['variables'].each do |var|
              if var['name'] == args[0]
                dap_output "#{args[0]} : #{var['value']}"
              end
            end
          end
        end
      end
    end

    def dap_show(args = [])
      return if args == []

      @frame.view_win.sci_newline
      if 'capabilities'.start_with? args[0]
        @dap_client.adapter_capabilities.each do |key, value|
          dap_output "#{key}: #{value}"
        end
      end
    end
  end
end
