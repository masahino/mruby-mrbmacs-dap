assert('dap_launch stores and sends launch arguments') do
  app, client = setup_dap_test_application

  app.dap_launch(['a.out', 'first', 'second'])

  arguments = { 'program' => 'a.out', 'args' => ['first', 'second'] }
  assert_equal [[:launch, arguments]], client.calls
  assert_equal arguments, app.instance_variable_get(:@dap_launch_arguments)
end

assert('dap_launch can launch again on the same client after terminated') do
  app, client = setup_dap_test_application

  app.dap_launch(['a.out'])
  app.dap_process_event('terminated', {})
  app.dap_launch(['a.out'])

  expected = [:launch, { 'program' => 'a.out', 'args' => [] }]
  assert_equal [expected, expected], client.calls
  assert_equal 0, app.stop_count
end

assert('dap_attach sends an integer pid from a process completion candidate') do
  app, client = setup_dap_test_application

  app.dap_attach(['a.out:37526'])

  assert_equal [[:attach, { 'program' => 'a.out', 'pid' => 37526 }]], client.calls
end

assert('dap_attach sends an integer pid when given only a pid') do
  app, client = setup_dap_test_application

  app.dap_attach(['37526'])

  assert_equal [[:attach, { 'pid' => 37526 }]], client.calls
end

assert('dap_attach sends a program name when given only a name') do
  app, client = setup_dap_test_application

  app.dap_attach(['a.out'])

  assert_equal [[:attach, { 'program' => 'a.out' }]], client.calls
end

assert('dap_restart sends the saved launch arguments') do
  app, client = setup_dap_test_application
  launch_arguments = { 'program' => 'a.out', 'args' => ['first'] }
  app.instance_variable_set(:@dap_launch_arguments, launch_arguments)
  client.adapter_capabilities['supportsRestartRequest'] = true

  app.dap_restart

  assert_equal [[:restart, { 'arguments' => launch_arguments }]], client.calls
end

assert('dap_restart reports an unsupported restart request') do
  app, client = setup_dap_test_application

  app.dap_restart

  assert_equal [], client.calls
  assert_equal ['restart Request not supported'], app.outputs
end

assert('dap_run sends configurationDone when supported') do
  app, client = setup_dap_test_application
  client.adapter_capabilities['supportsConfigurationDoneRequest'] = true

  app.dap_run

  assert_equal [[:configurationDone]], client.calls
end

assert('dap_run reports an unsupported configurationDone request') do
  app, client = setup_dap_test_application

  app.dap_run

  assert_equal [], client.calls
  assert_equal ['configurationDone Request not supported'], app.outputs
end
