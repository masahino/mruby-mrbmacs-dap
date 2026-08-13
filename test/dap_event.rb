assert('terminated keeps the adapter available for another launch') do
  app, client = setup_dap_test_application

  app.dap_process_event('terminated', {})

  assert_same client, app.dap_client
  assert_equal 0, app.stop_count
  assert_equal ['[Terminated]'], app.outputs
  assert_equal 'terminated', app.dap_last_event
  assert_equal 1, app.prompt_count
end

assert('initialized prepares the client') do
  app, client = setup_dap_test_application

  app.dap_process_event('initialized', {})

  assert_equal [[:initialized]], client.calls
end

assert('capabilities updates adapter capabilities from the event body') do
  app, client = setup_dap_test_application
  capabilities = {
    'supportsRestartRequest' => true,
    'supportsConfigurationDoneRequest' => true
  }

  app.dap_process_event('capabilities', 'capabilities' => capabilities)

  assert_equal [[:update_adapter_capabilities, capabilities]], client.calls
  assert_equal true, client.adapter_capabilities['supportsRestartRequest']
end

assert('breakpoint event displays a source location') do
  app, = setup_dap_test_application
  body = {
    'reason' => 'changed',
    'breakpoint' => {
      'id' => 1,
      'source' => { 'path' => '/tmp/test.c' },
      'line' => 9,
      'column' => 7
    }
  }

  app.dap_event_breakpoint(body)

  assert_equal ['[Breakponit] changed: /tmp/test.c:9:7'], app.outputs
end

assert('breakpoint event displays an instruction location') do
  app, = setup_dap_test_application
  body = {
    'reason' => 'new',
    'breakpoint' => {
      'id' => 2,
      'instructionReference' => '0x100000470',
      'line' => 9
    }
  }

  app.dap_event_breakpoint(body)

  assert_equal ['[Breakponit] new: 0x100000470:9'], app.outputs
end

assert('breakpoint event falls back to its id') do
  app, = setup_dap_test_application
  body = { 'reason' => 'removed', 'breakpoint' => { 'id' => 3 } }

  app.dap_event_breakpoint(body)

  assert_equal ['[Breakponit] removed: breakpoint 3'], app.outputs
end

assert('stopped requests and displays the top stack frame') do
  app, client = setup_dap_test_application
  client.stack_trace_response = {
    'success' => true,
    'body' => {
      'stackFrames' => [{
        'id' => 524_288,
        'name' => 'main',
        'source' => { 'path' => '/tmp/test.c' },
        'line' => 9
      }]
    }
  }

  app.dap_event_stopped('threadId' => 12)

  assert_equal [[:stackTrace, { 'threadId' => 12, 'levels' => 1 }]], client.calls
  assert_equal 12, app.instance_variable_get(:@dap_thread_id)
  assert_equal 524_288, app.instance_variable_get(:@dap_frame_id)
  assert_equal ['/tmp/test.c', 8], app.shown_position
  assert_equal ['[Stopped] 524288: main /tmp/test.c:9'], app.outputs
end

assert('stopped does not display a frame after a failed stackTrace') do
  app, client = setup_dap_test_application
  client.stack_trace_response = { 'success' => false }

  app.dap_event_stopped('threadId' => 12)

  assert_nil app.shown_position
  assert_equal [], app.outputs
end
