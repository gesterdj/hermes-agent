## ADDED Requirements

### Requirement: Interrupt reaches every active HTTP transport
When Hermes interrupts an in-flight OpenAI-compatible request, the system SHALL attempt transport-level cancellation across the client's default transport and configured mounted transports.

#### Scenario: Request uses the default transport
- **WHEN** an interrupted request has an active socket in the default HTTPX transport pool
- **THEN** Hermes shuts down that socket to unblock the request worker

#### Scenario: Request uses a mounted transport
- **WHEN** an interrupted request has an active socket only in an HTTPX mounted transport pool
- **THEN** Hermes shuts down that socket to unblock the request worker

### Requirement: Cancellation is identity-safe
The system SHALL shut down each discovered raw socket at most once during a cancellation attempt, including when transports, pools, connections, or sockets are reachable through multiple mount entries.

#### Scenario: Mount aliases share a transport
- **WHEN** multiple mount entries reference the same transport or underlying socket
- **THEN** Hermes invokes socket shutdown exactly once for that raw socket

### Requirement: Cancellation preserves file-descriptor ownership
The interrupting thread MUST use full-duplex socket shutdown to unblock network I/O and MUST NOT close the socket file descriptor directly.

#### Scenario: Active socket is cancelled
- **WHEN** Hermes performs transport-level cancellation on an active socket
- **THEN** it invokes `shutdown(SHUT_RDWR)` and leaves final file-descriptor closure to the owning HTTPX worker

### Requirement: Transport inspection is best-effort
The system SHALL tolerate missing, lazy, unsupported, or failing private transport internals without raising from cancellation and SHALL continue inspecting independent candidate transports when possible.

#### Scenario: One custom mount is unsupported
- **WHEN** one mounted transport cannot be inspected and a later mounted transport contains the active socket
- **THEN** Hermes continues traversal and shuts down the socket in the inspectable transport

#### Scenario: Request already completed
- **WHEN** cancellation cleanup finds no active socket because the request has already completed
- **THEN** cleanup completes without error and reports that zero sockets were force-shut down

### Requirement: Backend generation stops on disconnect
For a streaming OpenAI-compatible request whose server honors client disconnect, an interrupt SHALL cause the server-side stream to observe disconnection promptly rather than Hermes consuming the cancelled stream through EOS.

#### Scenario: Local streaming backend is interrupted
- **WHEN** Hermes interrupts a stream routed through a mounted direct HTTP transport while the backend is still generating
- **THEN** the backend observes connection termination before producing its complete response
- **AND** cancelled chunks are not delivered to the active conversation output
