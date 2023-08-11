assert('dap_arg_file') do
  list = Dir.entries('./')
  assert_equal list, Mrbmacs::DapMode.suggest_file_completion('')

  list = Dir.entries('mrblib').map { |e| "mrblib/#{e}" }
  assert_equal list, Mrbmacs::DapMode.suggest_file_completion('mrblib/')

  list = Dir.entries('mrblib').select { |e| e.start_with?('m') }.map { |e| "mrblib/#{e}" }
  assert_equal list, Mrbmacs::DapMode.suggest_file_completion('mrblib/m')

  list = Dir.entries('/').map { |e| "/#{e}" }
  assert_equal list, Mrbmacs::DapMode.suggest_file_completion('/')

  list = Dir.entries('/').select { |e| e.start_with?('t') }.map { |e| "/#{e}" }
  assert_equal list, Mrbmacs::DapMode.suggest_file_completion('/t')
end
