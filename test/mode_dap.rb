assert('dap_method') do
  assert_equal :dap_launch, Mrbmacs::DapMode.dap_method('launch')
  assert_equal :dap_launch, Mrbmacs::DapMode.dap_method('l')
  assert_equal :dap_continue, Mrbmacs::DapMode.dap_method('con')
  assert_equal :dap_run, Mrbmacs::DapMode.dap_method('confi')
end
