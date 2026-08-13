# mruby-mrbmacs-dap

DAP (Debug Adapter Protocol) support for mrbmacs.

User configuration and commands are documented in the
[mrbmacs DAP guide](https://github.com/masahino/mrbmacs/blob/main/docs/dap.md).
Protocol sequencing and implementation notes are documented in
[Session lifecycle](docs/session-lifecycle.md).

## Architecture

`mruby-mrbmacs-dap` is the user-facing part of the debugging system. It provides
the DAP buffer, commands, completion, breakpoint markers, and source navigation.

For ordinary native debugging, it communicates with a debug adapter through
[`mruby-dap-client`](https://github.com/masahino/mruby-dap-client):

```text
mrbmacs
  -> mruby-mrbmacs-dap
  -> mruby-dap-client
  -> native debug adapter
  -> debug target
```

Debugging mruby source code adds two components:

```text
mrbmacs
  -> mruby-mrbmacs-dap
  -> mruby-dap-client
  -> mruby-bin-dap-proxy
  -> native debug adapter (for example, lldb-dap)
  -> an mruby executable built with mruby-debug
```

- [`mruby-dap-client`](https://github.com/masahino/mruby-dap-client) starts the
  configured adapter and exchanges DAP messages.
- [`mruby-bin-dap-proxy`](https://github.com/masahino/mruby-bin-dap-proxy)
  translates mruby source breakpoints, stack frames, variables, and stepping to
  operations understood by the native debug adapter.
- [`mruby-debug`](https://github.com/masahino/mruby-debug) exposes the current
  mruby source location and variable information to the native debugger.

The executable name used by the default mruby configuration is
`mruby-dap-proxy`. The executable found through `PATH` is used, so verify it
when a local build and an installed copy both exist:

```sh
command -v mruby-dap-proxy
```

## Starting a session

Run the mrbmacs `dap` command and select a debugger configuration. The default
mruby configuration starts `mruby-dap-proxy`, which then starts its native debug
adapter.

The DAP buffer accepts commands including:

- `launch PROGRAM [ARG ...]`
- `attach PID` or `attach PROGRAM`
- `break FILE:LINE` or `break FUNCTION`
- `run`
- `step`, `next`, `continue`, and `finish`
- `scopes`, `variables`, `evaluate`, and `p`
- `restart`
- `terminate`
- `help`

`restart` sends the DAP `restart` request to a live adapter session when the
adapter advertises `supportsRestartRequest`. A completed session reported by a
`terminated` event has a different lifecycle; see
[Session lifecycle](docs/session-lifecycle.md).

`launch` currently passes `PROGRAM` to the debug adapter without resolving it
relative to the current buffer or working directory. Some adapters therefore
require an absolute path.

## Diagnostics

Adapter standard error is written to the logfile managed by `mruby-dap-client`.
The default path is under the system temporary directory and contains the
adapter command name and process ID.

The current startup path contains multiple external processes. A startup failure
may come from the proxy command, the native debug adapter, or the target program.
The current client reports some startup failures only as `error`; inspect the
adapter logfile and verify each executable with `command -v`.

The mrbmacs logfile records complete DAP messages. The DAP buffer intentionally
shows a smaller user-facing set of process, stop, output, exit, termination, and
breakpoint information.

## Known adapter limitations

Current `lldb-dap` may retain source-breakpoint objects belonging to the
previous LLDB target when a second `launch` is sent on the same connection after
`terminated`. Although `setBreakpoints` returns success, execution may not stop
at the breakpoint in the new target. This is documented as a current adapter
limitation rather than an mrbmacs breakpoint-configuration omission. See
[Relaunch after termination](docs/session-lifecycle.md#relaunch-after-termination).

## Supported frontends

- [mrbmacs-curses](https://github.com/masahino/mruby-bin-mrbmacs-curses)
- [mrbmacs-termbox](https://github.com/masahino/mruby-bin-mrbmacs-termbox)
- [mrbmacs-gtk](https://github.com/masahino/mruby-bin-mrbmacs-gtk)
- [mrbmacs-cocoa](https://github.com/masahino/mruby-bin-mrbmacs-cocoa)

## Screenshot

![dap_ruby](https://user-images.githubusercontent.com/381912/202875723-09d645f2-f3e7-4dbe-9cda-ae52dd749cde.gif)
