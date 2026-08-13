# DAP Session Lifecycle

This document describes the DAP message flow implemented by
`mruby-mrbmacs-dap` and the responsibilities of its related components. It is
intended for maintainers and for diagnosing adapter-specific behavior. User
commands and configuration are documented in the
[mrbmacs DAP guide](https://github.com/masahino/mrbmacs/blob/main/docs/dap.md).

## Responsibilities

| Component | Responsibility |
| --- | --- |
| `mruby-mrbmacs-dap` | DAP buffer, commands, event and response presentation, breakpoint markers, source navigation |
| `mruby-dap-client` | Adapter process and transport, request sequencing, capabilities, stored source breakpoints |
| `mruby-bin-dap-proxy` | Translation between mruby source-level operations and a native debug adapter |
| `mruby-debug` | mruby debug hook and native functions used to inspect mruby execution |
| Native adapter | Debuggee lifecycle, native breakpoints, stepping, stack frames, variables |

Frontend implementations provide event-loop and Scintilla integration. DAP
protocol behavior remains in the extension and client and is shared by Curses,
Termbox, GTK, and Cocoa.

## Initial adapter startup

The mrbmacs `dap` command selects a configuration, starts or connects to a DAP
adapter, and sends `initialize`:

```text
mrbmacs                       adapter
   |                             |
   | start adapter / open IO     |
   |---------------------------->|
   | initialize                  |
   |---------------------------->|
   | initialize response         |
   |<----------------------------|
   | register IO read handler    |
```

Adapter capabilities from the initialize response are stored by
`mruby-dap-client`. A later DAP `capabilities` event updates that stored set.

## Launch and configuration

`launch` and `run` are separate mrbmacs commands:

```text
mrbmacs                       adapter
   | launch                      |
   |---------------------------->|
   | initialized                 |
   |<----------------------------|
   | setBreakpoints              |
   |---------------------------->|
   | setBreakpoints response     |
   |<----------------------------|
   | configurationDone (`run`)   |
   |---------------------------->|
   | process / stopped / output  |
   |<----------------------------|
```

`DAP::Client#initialized` sends every source breakpoint stored in
`source_breakpoints`. This supports breakpoints selected with `C-x SPC` before
the target is launched.

The launch response may be delayed by the adapter until `configurationDone`.
Asynchronous events and responses can therefore be interleaved. Message framing
must consume exactly the declared `Content-Length` before reading the next
message.

## Stopped processing

On `stopped`, `mruby-mrbmacs-dap` stores `threadId` and requests the top stack
frame:

```text
stopped
  -> stackTrace(threadId, levels: 1)
  -> store frameId
  -> open the source path
  -> display the current-position marker
```

Step, next, continue, pause, and finish requests use the most recently reported
thread ID. They are not valid before the adapter has supplied a stopped thread.

## Restart

The `restart` DAP-buffer command sends the standard DAP request only when the
adapter advertises `supportsRestartRequest`:

```json
{
  "command": "restart",
  "arguments": {
    "arguments": {
      "program": "/absolute/path/to/program",
      "args": []
    }
  }
}
```

The nested `arguments.arguments` member is required by `RestartArguments`: the
inner object is the latest launch configuration.

A restart request operates on the current adapter session. It does not repeat
the DAP `initialize` request, and a client must not send another
`configurationDone` unless the adapter starts a new configuration sequence by
emitting `initialized`.

Adapters implement restart differently:

- `lldb-dap` kills or replaces the process, launches from its saved launch
  request, and continues internally.
- CodeLLDB terminates the debuggee and completes another launch while retaining
  its debug session.
- Delve restarts its debugger and emits `initialized`; its tests verify that
  configured breakpoints are hit after restart.

## Exit and termination

The events have different meanings:

```text
exited      the debuggee supplied an exit code
terminated debugging of that debuggee has ended
```

`terminated` does not by itself mean that the adapter process or its transport
has closed. `mruby-mrbmacs-dap` currently keeps the adapter IO registered and
returns to the DAP prompt.

Some adapters treat `terminated` as the end of the complete adapter session.
For example, debugpy finalizes its session and expects the client to disconnect.
Other adapters may continue accepting requests. Accepting a request does not,
by itself, guarantee that all per-target adapter state has been reset.

## Relaunch after termination

Current `lldb-dap` accepts another `launch` request on the same connection after
`terminated` and performs the normal configuration exchange:

```text
terminated
launch
initialized
setBreakpoints -> success, verified: true
configurationDone
continued
```

However, the new process may run to completion without stopping at the source
breakpoint.

### Cause in lldb-dap

`lldb-dap` stores source breakpoints in a map keyed by source path and source
position. When the second launch supplies the same path, line, and column,
`DAP::SetSourceBreakpoints` finds the previous entry and calls
`UpdateBreakpoint`. It does not first verify that the LLDB breakpoint ID exists
in the newly created target and does not call `SetBreakpoint` again.

The response can consequently describe the breakpoint from the previous target
as verified even though the new target has no effective breakpoint.

This differs from CodeLLDB, which looks up the saved breakpoint ID in the
current target and creates a new breakpoint when the ID is absent. Delve's
restart implementation also has explicit tests that require a preserved
breakpoint to be hit after restart. debugpy instead treats termination as a
session-finalization boundary.

For now, mrbmacs documents same-connection relaunch after `terminated` as an
`lldb-dap` limitation. A fresh adapter session avoids carrying the stale
per-target breakpoint cache into the next launch.

Potential future approaches are deliberately not part of the current behavior:

- close the adapter and initialize a new session after `terminated`;
- clear adapter breakpoint lists before resending the stored lists;
- rely on an upstream `lldb-dap` change that recreates breakpoints for a new
  target.

Each approach changes session semantics and must be evaluated across adapters
before implementation.

## Logging and diagnostics

The DAP buffer is a user-facing console and intentionally suppresses much of the
raw protocol traffic. Complete received messages are recorded through the
mrbmacs logger. Adapter standard error is written to the separate logfile
created by `mruby-dap-client`.

When diagnosing a lifecycle problem, retain these messages in order:

1. request and response for `initialize`;
2. request for `launch` or `restart`;
3. `initialized` event;
4. breakpoint requests and responses;
5. `configurationDone` request and response;
6. `process`, `continued`, `stopped`, `exited`, and `terminated` events.

Do not infer adapter state from the displayed prompt alone. The prompt only
indicates that mrbmacs accepts another command.

## Test boundaries

`mruby-mrbmacs-dap` unit tests use a mock DAP client to verify command routing,
event dispatch, stored launch arguments, output formatting, and the intended
behavior after `terminated`. Transport framing and generic breakpoint storage
belong to `mruby-dap-client` tests. Adapter-specific lifecycle behavior requires
an integration test with the selected adapter and should not be assumed from a
mock response.
