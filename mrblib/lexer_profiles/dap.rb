module Mrbmacs
  DAP_STYLE_DEFAULT = 0
  DAP_STYLE_FILE = 1
  DAP_STYLE_NUMBER = 2
  DAP_STYLE_PATTERN = 3
  DAP_STYLE_STRING = 4
  DAP_STYLE_PROMPT = 5

  DAP_LEXER_PROFILE = LexerProfile.new(
    :dap,
    nil,
    {
      DAP_STYLE_DEFAULT => :default,
      DAP_STYLE_FILE => :markup_link,
      DAP_STYLE_NUMBER => :number,
      DAP_STYLE_PATTERN => :warning,
      DAP_STYLE_STRING => :string,
      DAP_STYLE_PROMPT => :comment
    }
  )
end
