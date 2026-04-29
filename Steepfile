D = Steep::Diagnostic

target :lib do
  signature "sig"

  check "lib"

  library "logger"
  library "delegate"
  library "json"

  configure_code_diagnostics(D::Ruby.default) do |hash|
    # OpenSearch::Sugar::Client extends SimpleDelegator; delegated methods (e.g. `indices`,
    # `cluster`) are resolved dynamically at runtime and cannot be statically typed.
    hash[D::Ruby::NoMethod] = :information

    # opensearch-ruby and other third-party gems ship no RBS; suppress noise from
    # unresolvable constants and untyped collection literals that arise at their boundaries.
    hash[D::Ruby::UnknownConstant] = :information
    hash[D::Ruby::UnannotatedEmptyCollection] = :information
    hash[D::Ruby::ArgumentTypeMismatch] = :information
  end
end
