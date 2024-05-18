module Mrbmacs
  # DAP mode
  class DapMode < Mode
    def self.suggest_process_completion(input_str)
      candidates = []
      if Scintilla::PLATFORM != :CURSES_WIN32
        ps_out = `ps`
        ps_out.each_line do |line|
          elements = line.split
          next if elements[0] == 'PID' || elements[3][0] == '-'

          candidates.push "#{elements[3]}:#{elements[0]}"
        end
      end
      candidates.sort.select { |e| e.start_with?(input_str) }
    end

    def self.suggest_file_completion(input_str)
      file_list = []
      if !input_str.include?('/')
        Dir.foreach('.') do |item|
          file_list << item
        end
      elsif input_str.end_with?('/')
        file_list = Dir.entries(input_str).map { |e| File.join(input_str, e) } if File.exist?(input_str)
      else
        dir = File.dirname(input_str)
        fname = File.basename(input_str)
        if File.exist?(dir)
          Dir.foreach(dir) do |item|
            file_list << File.join(dir, item) if item.start_with?(fname)
          end
        end
      end
      file_list
    end

    def self.suggest_show_completion(_input_str)
      ['capabilities']
    end
  end
end
