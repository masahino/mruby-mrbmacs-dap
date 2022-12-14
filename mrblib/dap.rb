module Mrbmacs
  # DAPExtension
  class DAPExtension < Extension
    DAP_BUFFER_NAME = '*dap*'.freeze
    DAP_LIST_TYPE = 98
    DAP_DEFAULT_CONFIG = {
      'cpp' => {
        command: 'lldb-vscode',
        args: [],
        type: 'lldb-vscode',
        langs: ['cpp']
        # command: "#{ENV['HOME']}/.vscode/extensions/vadimcn.vscode-lldb-1.7.4/adapter/codelldb",
        # args: ['--port 4711'],
        # type: 'lldb',
        # port: 4711
      },
      'mruby' => {
        command: 'mruby-dap-proxy',
        args: [],
        type: 'lldb-vscode',
        langs: %w[ruby cpp]
      },
      'mruby-port' => {
        command: 'mruby-dap-proxy',
        args: ['--port', 1234],
        type: 'lldb-vscode',
        port: 1234,
        langs: %w[ruby cpp]
      },
      'mruby-codelldb' => {
        command: 'mruby-dap-proxy',
        args: ['-l', "#{ENV['HOME']}/.vscode/extensions/vadimcn.vscode-lldb-1.7.4/adapter/codelldb",
               '--adapter_port', 1234,
               '--adapter_type', 'lldb'],
        type: 'lldb',
        langs: %w[ruby cpp]
      },
      'rdbg' => {
        command: 'rdbg',
        args: ['-O', "--sock-path=/tmp/mrbmacs-rdbg-#{$PID}"],
        type: 'rdbg',
        langs: ['ruby'],
        sock_path: "/tmp/mrbmacs-rdbg-#{$PID}",
        require_target: true
      }
    }.freeze

    DAP_DEFAULT_KEYMAP = {
      'C-x  ' => 'dap-toggle-breakpoint'
    }.freeze

    def self.register_dap_client(appl)
      Mrbmacs::Mode.add_mode(DAP_BUFFER_NAME, 'dap')
      appl.ext.data['dap'] = {}
      if appl.config.ext['dap'].nil?
        appl.config.ext['dap'] = DAP_DEFAULT_CONFIG
      else
        appl.config.ext['dap'] = DAP_DEFAULT_CONFIG.merge appl.config.ext['dap']
      end

      appl.config.ext['dap'].each do |key, value|
        appl.ext.data['dap'][key] = DAP::Client.new(value[:command],
                                                    { 'args' => value[:args],
                                                      'port' => value[:port],
                                                      'sock_path' => value[:sock_path],
                                                      'type' => value[:type] })
        value[:langs].each do |lang|
          Mrbmacs::DAPExtension.set_keybind(appl, lang)
        end
      end

      appl.add_command_event(:after_find_file) do |app, filename|
        app.dap_mark_breakpoints(filename)
      end

      appl.add_sci_event(Scintilla::SCN_MARGINCLICK) do |app, scn|
        app.dap_toggle_breakpoint(scn['position'])
      end

      appl.add_command_event(:before_save_buffers_kill_terminal) do |app|
        app.ext.data['dap'].each do |_lang, client|
          if client.status != :stop
            client.stop_adapter
          end
        end
      end
    end

    def self.set_keybind(_app, lang)
      mode = Mrbmacs::Mode.get_mode_by_name(lang)
      unless mode.nil?
        DAP_DEFAULT_KEYMAP.each do |k, v|
          mode.keymap[k] = v
        end
      end
    end
  end
end
