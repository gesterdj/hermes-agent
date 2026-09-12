## Context

Hermes interrupts an in-flight OpenAI-compatible request by marking the stream attempt cancelled and calling `force_close_tcp_sockets()`. Socket discovery currently descends only through `http_client._transport._pool`. The keepalive client builder installs explicit `http://` and `https://` transports in `http_client._mounts`, so a request to a direct local endpoint can live entirely outside the inspected default pool. In that case the UI correctly rejects stale deltas, but the worker keeps reading and the inference server keeps generating until EOS.

Cleanup intentionally calls `socket.shutdown(SHUT_RDWR)` without `socket.close()`. That ownership rule prevents the cross-thread FD-reuse corruption fixed in #29507 and must remain unchanged.

## Goals / Non-Goals

**Goals:**

- Discover sockets below the default HTTPX transport and all mounted transports.
- Shut each raw socket down no more than once, even if transport aliases share objects.
- Keep traversal defensive against absent, lazy, custom, or version-dependent HTTPX/httpcore internals.
- Cover the actual client topology created for direct OpenAI-compatible endpoints.
- Preserve the existing owning-thread FD-close contract.

**Non-Goals:**

- Adding a user-facing cancellation switch or provider-specific llama.cpp behavior.
- Calling `socket.close()` from the interrupting thread.
- Replacing HTTPX, relying on a new dependency, or redesigning the streaming worker lifecycle.
- Treating `tcp_force_closed=0` as an error after a request has already completed naturally.

## Decisions

### Traverse a collection of transports

Socket discovery will build a candidate collection containing `http_client._transport` and every value in `http_client._mounts`, when present. It will then inspect each candidate's `_pool` using the existing connection and stream compatibility logic.

This targets the exact mismatch while retaining support for the default transport. Changing the client builder to avoid mounts was rejected because mounts intentionally provide scheme-specific transport configuration and changing them would couple cancellation to unrelated TLS/proxy/keepalive behavior.

### Deduplicate by object identity at every shared layer

Traversal will maintain identity sets for transports, pools, connection entries, and raw sockets. This handles mount pattern aliases and custom layouts that reference the same underlying objects. Socket identity remains the final guarantee that `shutdown()` runs once.

Deduplicating only sockets was considered sufficient for correctness, but earlier deduplication avoids repeatedly walking a shared pool and reduces exposure to mutable private internals during cancellation.

### Preserve best-effort private-internal traversal

Each candidate transport/pool is isolated from failures. A malformed custom mount must not prevent inspection of later valid mounts, and exceptions remain contained by the cleanup boundary. Existing compatibility paths for `_connections` versus `_pool`, wrapped `_connection`, `_network_stream` versus `_stream`, and AnyIO raw sockets remain intact.

Using only public HTTPX APIs was considered, but HTTPX exposes no public API to locate and synchronously abort the active raw socket from the interrupting thread. Closing the whole client in that thread was rejected because of the existing ownership and shared-client hazards.

### Test behavior, including the production mount topology

Unit tests will construct default-only, mount-only, shared/aliased, and malformed-plus-valid transport graphs and assert socket shutdown counts. A higher-level regression test will use the real client builder or a faithful HTTPX transport configuration and exercise `stream_interrupt_abort`, asserting that the server-side streaming generator observes disconnect/cancellation promptly rather than being drained to EOS.

The higher-level test must not assert private enumeration counts or a particular HTTPX mount-key representation. Its contract is the relationship between interrupt and backend disconnect.

## Risks / Trade-offs

- **HTTPX/httpcore private layouts can change** → Keep feature-detected traversal, retain all existing compatibility paths, and test against the installed real libraries.
- **The same socket may appear through several mounts** → Deduplicate by identity and assert exactly one shutdown in regression tests.
- **A custom transport accessor may raise** → Isolate candidate discovery/traversal failures so other transports are still inspected.
- **Cross-thread FD reuse could regress** → Continue using only `shutdown(SHUT_RDWR)`; explicitly assert that `close()` is never invoked.
- **An integration test could be timing-sensitive** → Use synchronization events and bounded waits around a local streaming server rather than sleeps or token-count timing.

## Migration Plan

No configuration or data migration is required. Ship the traversal change with regression tests. Rollback is a code revert; existing stream fencing continues to prevent stale UI output if rollback becomes necessary.

## Open Questions

- During implementation, confirm whether the installed HTTPX version stores mount values directly as transports or occasionally as lazy wrappers; if wrappers occur, support only the minimal feature-detected unwrapping demonstrated by a real client instance.
