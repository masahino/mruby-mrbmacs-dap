MRuby::Gem::Specification.new('mruby-mrbmacs-dap') do |spec|
  spec.license = 'MIT'
  spec.authors = 'masahino'

  spec.add_dependency 'mruby-dap-client', :github => 'masahino/mruby-dap-client', :branch => 'main'
  spec.add_dependency 'mruby-mrbmacs-base', :github => 'masahino/mruby-mrbmacs-base'
  spec.add_dependency 'mruby-which', :github => 'masahino/mruby-which'
end
