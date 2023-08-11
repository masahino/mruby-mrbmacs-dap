assert('dap_method') do
  assert_equal :dap_launch, Mrbmacs::DapMode.dap_method('launch')
  assert_equal :dap_launch, Mrbmacs::DapMode.dap_method('l')
  assert_equal :dap_continue, Mrbmacs::DapMode.dap_method('con')
  assert_equal :dap_run, Mrbmacs::DapMode.dap_method('confi')
end

assert('dap_arg_type') do
  assert_equal nil, Mrbmacs::DapMode.dap_arg_type('run')
  assert_equal nil, Mrbmacs::DapMode.dap_arg_type('n')
  assert_equal nil, Mrbmacs::DapMode.dap_arg_type('con')
  assert_equal nil, Mrbmacs::DapMode.dap_arg_type('step')
end
