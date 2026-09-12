## 1. Characterize the Runtime Transport Graph

- [x] 1.1 Add a focused test fixture that represents the default transport plus HTTPX mount values produced by `_build_keepalive_http_client()`.
- [x] 1.2 Confirm with the installed HTTPX version whether mount values require any lazy-wrapper unwrapping, and record only demonstrated compatibility handling in the implementation.

## 2. Extend Socket Discovery

- [x] 2.1 Refactor `_iter_pool_sockets()` to inspect the default transport and every mounted transport while retaining existing httpcore connection/stream compatibility paths.
- [x] 2.2 Deduplicate transports, pools, connection entries, and raw sockets by identity without allowing a failing custom transport to stop traversal of independent transports.
- [x] 2.3 Preserve `force_close_tcp_sockets()` semantics: invoke `shutdown(SHUT_RDWR)`, never `close()`, contain cleanup exceptions, and return the number of unique sockets handled.

## 3. Add Regression Coverage

- [x] 3.1 Add unit coverage for a socket reachable only through a mounted transport and verify `tcp_force_closed` would count it.
- [x] 3.2 Add unit coverage for default-plus-mounted and aliased/shared transport graphs, asserting each socket is shut down exactly once.
- [x] 3.3 Add unit coverage proving an unsupported or failing mount does not prevent cleanup through another valid mount and an empty/already-completed client remains non-fatal.
- [x] 3.4 Retain or strengthen the regression assertion that interrupt cleanup never calls `socket.close()` from the interrupting thread.
- [x] 3.5 Add a synchronized local OpenAI-compatible streaming regression test that routes through the production-style mounted HTTP transport, interrupts mid-stream, and proves the server observes disconnect before EOS with no cancelled deltas reaching active output.

## 4. Validate the Fix

- [x] 4.1 Run the focused socket cleanup and streaming interrupt test modules.
- [x] 4.2 Run the broader run-agent interrupt, stale-stream, and OpenAI client lifecycle regression suites.
- [ ] 4.3 Perform a container smoke test against llama.cpp and confirm an interrupted request logs `stream_interrupt_abort` with `tcp_force_closed` greater than zero and llama.cpp stops generation promptly.
