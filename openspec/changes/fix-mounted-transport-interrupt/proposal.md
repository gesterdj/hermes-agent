## Why

Interrupting an OpenAI-compatible streaming request can leave local inference servers generating until EOS because Hermes cannot find the active socket when HTTPX routes the request through a mounted transport. The existing stale-stream fence protects the UI from late output, but it does not release the backend's compute allocation.

## What Changes

- Make transport socket discovery cover both the client's default transport and transports registered in HTTPX mounts.
- Deduplicate transports, pools, connections, and sockets so aliases or shared mounts are shut down at most once.
- Preserve best-effort cleanup across HTTPX/httpcore versions and custom transports: unsupported or partially initialized internals remain non-fatal.
- Add behavior-focused regression coverage proving that interrupt cleanup reaches a socket used by a mounted direct HTTP transport and preserves existing default-transport behavior.
- Validate the real OpenAI-compatible streaming path so cancellation closes the connection rather than merely suppressing subsequent chunks.

## Capabilities

### New Capabilities

- `stream-transport-cancellation`: Reliable transport-level cancellation of interrupted model requests, including requests routed through mounted HTTPX transports.

### Modified Capabilities

None.

## Impact

- Affected code: `agent/agent_runtime_helpers.py` and interrupt/client cleanup call paths exposed through `run_agent.py`.
- Affected tests: socket cleanup unit tests plus an OpenAI-compatible streaming interrupt regression test.
- External behavior: llama.cpp and other OpenAI-compatible servers should observe client disconnect promptly after an interrupt.
- APIs/configuration: no public API, model-tool schema, environment variable, or `config.yaml` change.
- Dependencies: no new dependency; the implementation remains compatible with the currently supported HTTPX/httpcore internals.
