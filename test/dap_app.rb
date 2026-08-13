module Mrbmacs
  class DapReadMessageTestApplication < DapTestApplication
    attr_reader :response, :event

    def dap_process_response(message)
      @response = message
    end

    def dap_process_event(event, body)
      @event = [event, body]
    end
  end
end

assert('dap_read_message dispatches a response') do
  app = Mrbmacs::DapReadMessageTestApplication.new
  client = Mrbmacs::DapTestClient.new
  message = {
    'type' => 'response',
    'request_seq' => 1,
    'command' => 'launch',
    'success' => true
  }
  client.message = message
  app.dap_client = client

  app.dap_read_message(nil)

  assert_same message, app.response
end

assert('dap_read_message dispatches an event') do
  app = Mrbmacs::DapReadMessageTestApplication.new
  client = Mrbmacs::DapTestClient.new
  body = { 'threadId' => 7 }
  client.message = { 'type' => 'event', 'event' => 'stopped', 'body' => body }
  app.dap_client = client

  app.dap_read_message(nil)

  assert_equal ['stopped', body], app.event
end

assert('dap_read_message reports an unknown message type') do
  app, client = setup_dap_test_application
  client.message = { 'type' => 'request' }

  app.dap_read_message(nil)

  assert_equal ['unknown DAP message [request]'], app.outputs
end

assert('dap_read_message stops the adapter after EOF') do
  app, client = setup_dap_test_application
  client.define_singleton_method(:wait_message) { raise EOFError }

  app.dap_read_message(nil)

  assert_equal 1, app.stop_count
end
