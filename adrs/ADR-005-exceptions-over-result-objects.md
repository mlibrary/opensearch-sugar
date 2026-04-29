# ADR-005: Exceptions for Error Handling; No Result/Either Objects

## Status

Accepted

## Date

2026-04-28

## Context

When a Sugar method fails — invalid arguments, OpenSearch returns an error, a multi-step
sequence partially succeeds — the gem must communicate that failure to the caller. Two broad
approaches were considered:

- **Exceptions**: raise a Ruby exception; callers use `begin/rescue` to handle errors
- **Result/Either objects**: return a value that is either a success wrapper or a failure
  wrapper, forcing callers to inspect the return value (e.g., `result.success?`,
  `result.value`, `result.error`)

The Result pattern (sometimes called Dry::Monads `Result`, `Either`, or a custom `Ok`/`Err`
type) is popular in functional-leaning Ruby code. Before settling on exceptions, a full
comparison of what the codebase would look like under each approach was produced and reviewed.

## Decision

We use Ruby exceptions for all error handling. Sugar raises `OpenSearch::Sugar::Error` (or a
more specific subclass) for errors that originate within the gem; errors from the underlying
`opensearch-ruby` transport layer are allowed to propagate as-is (i.e., as
`OpenSearch::Transport::Transport::Error` subclasses).

```ruby
# Sugar raises on failure
begin
  index = client.open_or_create("my_index")
  index.update_settings(settings)
rescue OpenSearch::Sugar::Error => e
  # Sugar-level error (e.g., invalid arguments, sequence failure)
  logger.error("Sugar error: #{e.message}")
rescue OpenSearch::Transport::Transport::Error => e
  # Raw transport error (e.g., connection refused, 4xx/5xx from OpenSearch)
  logger.error("OpenSearch error: #{e.message}")
end

# Methods that succeed simply return the result; no wrapper needed
count = index.count        # Integer
settings = index.settings  # Hash
```

The Result pattern was considered and summarized in full detail, but not adopted.

## Consequences

### Positive

- **Idiomatic Ruby**: exceptions are the standard Ruby error-handling mechanism; contributors
  and users familiar with Ruby (or any Ruby gem) will immediately understand the contract.
- **Clean happy path**: methods return their values directly with no wrapping. Callers that
  don't care about errors don't need to unwrap anything.
- **No new dependencies**: Result types would require either `dry-monads` or a custom
  implementation. Exceptions are built into the language.
- **Interoperability**: code that mixes Sugar calls with other Ruby libraries doesn't need
  an adapter layer to convert `Result` values to exceptions or vice versa.

### Negative

- **Errors are invisible in signatures**: a method's return type doesn't communicate what it
  can raise. Callers must read documentation or source to know which exceptions to handle.
- **Easy to ignore**: unlike a `Result` type, exceptions can be silently swallowed by an
  overly broad `rescue Exception` or `rescue StandardError` in the caller's code.
- **No enforced handling**: a compiler/type checker cannot require the caller to handle the
  error case (unlike `Result` in Rust or Haskell). Ruby's type system provides no enforcement.

### Neutral

- `OpenSearch::Sugar::Error < StandardError` is the base error class for all Sugar-originated
  exceptions. More specific subclasses should be introduced as distinct error categories emerge.
- Errors from the raw `opensearch-ruby` client propagate unchanged. Sugar does not wrap or
  re-raise transport exceptions except in cases where it needs to add context.
- The Result pattern summary produced during evaluation is preserved in `vibe/` as a reference
  for contributors who want to understand the tradeoff in detail.

## Alternatives Considered

**Result/Either objects (e.g., `dry-monads`)**
Evaluated in full. Rejected because:
- It adds a `dry-monads` dependency (or requires a custom implementation) to a gem that
  otherwise has minimal dependencies.
- It forces callers to adopt a monadic style that is not idiomatic in most Ruby codebases,
  especially non-Rails ones.
- The happy-path ergonomics worsen: every return value must be unwrapped before use.
- `opensearch-ruby` itself raises exceptions, so callers would still need `rescue` for
  transport errors; mixing `Result` and exceptions produces an inconsistent interface.

## Documentation Requirements

- REFERENCE must document `OpenSearch::Sugar::Error` and any subclasses with their meanings.
- HOWTO must include an error-handling section showing the recommended `rescue` pattern for
  both Sugar errors and raw transport errors.
- EXPLANATION should note that Result objects were considered and explain the rationale for
  choosing exceptions.
