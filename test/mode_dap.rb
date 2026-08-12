assert('dap_method') do
  assert_equal :dap_launch, Mrbmacs::DapMode.dap_method('launch')
  assert_equal :dap_launch, Mrbmacs::DapMode.dap_method('l')
  assert_equal :dap_continue, Mrbmacs::DapMode.dap_method('con')
  assert_equal :dap_run, Mrbmacs::DapMode.dap_method('confi')
end

assert('DapMode uses a container LexerProfile') do
  mode = Mrbmacs::DapMode.new

  assert_equal Mrbmacs::DAP_LEXER_PROFILE, mode.lexer_profile
  assert_nil mode.lexer_profile.lexer
  assert_equal :default, mode.lexer_profile.styles[Mrbmacs::DAP_STYLE_DEFAULT]
  assert_equal :markup_link, mode.lexer_profile.styles[Mrbmacs::DAP_STYLE_FILE]
  assert_equal :number, mode.lexer_profile.styles[Mrbmacs::DAP_STYLE_NUMBER]
  assert_equal :warning, mode.lexer_profile.styles[Mrbmacs::DAP_STYLE_PATTERN]
  assert_equal :string, mode.lexer_profile.styles[Mrbmacs::DAP_STYLE_STRING]
  assert_equal :comment, mode.lexer_profile.styles[Mrbmacs::DAP_STYLE_PROMPT]
end
