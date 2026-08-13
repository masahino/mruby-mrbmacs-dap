module Mrbmacs
  class DapResponseTestApplication < DapTestApplication
    attr_reader :marked_breakpoints

    def dap_mark_all_breakpoints
      @marked_breakpoints = true
    end
  end
end

assert('dap_output_response displays setBreakpoints locations') do
  app = Mrbmacs::DapResponseTestApplication.new
  message = {
    'command' => 'setBreakpoints',
    'body' => {
      'breakpoints' => [{
        'id' => 1,
        'source' => { 'path' => '/tmp/test.c' },
        'line' => 9
      }]
    }
  }

  app.dap_output_response(message)

  assert_true app.marked_breakpoints
  assert_equal ['[Breakpoints] 1: /tmp/test.c:9'], app.outputs
end

assert('dap_output_variables_response displays variables') do
  app, = setup_dap_test_application
  message = {
    'body' => {
      'variables' => [{ 'name' => 'total', 'value' => '6', 'type' => 'int' }]
    }
  }

  app.dap_output_variables_response(message)

  assert_equal ['total = 6 (int)'], app.outputs
end

assert('dap_process_response displays failed responses') do
  app, = setup_dap_test_application
  message = { 'command' => 'next', 'success' => false, 'message' => 'failed' }

  app.dap_process_response(message)

  assert_equal ['[response] fail', message], app.outputs
  assert_equal 1, app.prompt_count
end
