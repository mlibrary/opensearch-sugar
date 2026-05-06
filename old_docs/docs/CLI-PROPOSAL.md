# CLI Interface Proposal for opensearch-sugar

## Summary and Recommendation

A thin CLI wrapper around `opensearch-sugar` would be genuinely useful for a specific set of
operations: deploying and managing ML models, manipulating aliases, and performing bulk indexing
tasks that operators currently script by hand. These are workflows where a command-line interface
meaningfully reduces friction compared to writing one-off Ruby scripts.

**Recommendation: build it, but scope it narrowly.**

The argument for building: ML model lifecycle management (register, deploy, undeploy, delete) is
operationally complex, configuration-driven, and fundamentally a DevOps task rather than a
programming task. A CLI surfaces that workflow cleanly and makes it scriptable without requiring
the operator to write Ruby. Alias management follows the same logic — it is a routine deployment
operation, not something that belongs in application code.

The argument against overbuilding: OpenSearch ships a full-featured Dashboard UI. Recreating
index browse, search, or mapping visualisation in a CLI produces a worse experience than what
already exists, at real maintenance cost. The CLI should do things the Dashboard does poorly
(batch operations, scripting, ML model management) and deliberately omit things the Dashboard
does well (ad-hoc querying, visual mapping inspection, cluster monitoring).

The maintenance cost of the proposed scope is low. The command surface is small, `dry-cli`
handles argument parsing and help generation, and the implementation is almost entirely
delegation to the existing Sugar API — adding a new CLI command should take an hour, not a day.

---

## Potential Audiences

### Infrastructure / platform engineers
Operators who manage OpenSearch clusters for application teams. They need to automate index
creation, alias cutover (zero-downtime re-indexing), and ML model deployment as part of CI/CD
pipelines or runbooks. They are comfortable with shell scripting and expect commands to be
composable and scriptable (`--format json`, exit codes, stdin/stdout).

### Data engineers and ML practitioners
People who register and tune embedding models via ML Commons. The registration/deploy/undeploy
lifecycle is tedious via the raw REST API; a CLI with clear status feedback and idempotent
commands reduces the chance of leaving a cluster in a partially-deployed state. They may not
write Ruby day-to-day but they will run shell commands from a Makefile or a notebook.

### Application developers (secondary)
Developers building search features who want to inspect an index's mappings or analyzers, or
test an analyzer's tokenisation output against real text, without starting a Rails console or
writing a throwaway script. This use case is real but is equally well served by `pry` or
`bin/console` — the CLI advantage is marginal here.

### Who is *not* the audience
Non-technical users: the CLI requires credential management, understanding of OpenSearch
concepts, and comfort with a terminal. There is no case for making this accessible to users
who are not already technical. If non-technical access is a goal, it belongs in a web UI, not
a CLI.

---

## Use Cases and Proposed Command Surface

The proposed tool is named `os-sugar` (or `opensearch-sugar` if the gem ships an executable).
All commands respect `OPENSEARCH_URL`, `OPENSEARCH_USER`, and `OPENSEARCH_PASSWORD` from the
environment, with `--url`, `--user`, and `--password` flags available as overrides.

### Index management

```
os-sugar index list
  # Lists all index names in the cluster.
  # Useful for scripting, pipeline checks, and quick inspection.
  # The Dashboard does this well too, but the CLI version is scriptable.

os-sugar index create NAME [--no-knn]
  # Creates an index. Exits non-zero if it already exists (use open-or-create to be idempotent).

os-sugar index open-or-create NAME
  # Idempotent create. Useful in deploy scripts.

os-sugar index delete NAME [--force]
  # Deletes an index. Requires --force to prevent accidents.

os-sugar index exists NAME
  # Exits 0 if the index exists, 1 if not. Designed for shell conditionals.
```

**Opinion:** `list`, `exists`, and `open-or-create` are the highest-value commands here — they
slot directly into deployment scripts. `delete` with a `--force` guard is also valuable for
teardown automation. Creating and browsing indexes interactively is better done in the Dashboard.

### Alias management

Zero-downtime index re-indexing (blue/green) is one of the most common OpenSearch operational
tasks, and it is annoying to do via the REST API. A CLI makes the pattern scriptable.

```
os-sugar alias list INDEX
  # Lists all aliases for a given index.

os-sugar alias create INDEX ALIAS_NAME
  # Adds an alias to an index.

os-sugar alias swap ALIAS_NAME --from OLD_INDEX --to NEW_INDEX
  # Atomically removes the alias from OLD_INDEX and adds it to NEW_INDEX.
  # This is the core blue/green re-index operation. High value.
```

**Opinion:** `alias swap` is the single most compelling CLI command in this entire proposal. It
is a common, error-prone, multi-step operation that the REST API makes awkward and the Dashboard
does not support as a single atomic action. Building this alone would justify the CLI.

### ML model management

```
os-sugar models list
  # Lists all deployed models with their names, versions, and IDs.
  # Output is tabular by default; --format json for scripting.

os-sugar models register NAME VERSION [--format TORCH_SCRIPT]
  # Registers and deploys a model. Idempotent if the model already exists.
  # Polls until deployment is complete or fails. Prints status as it waits.

os-sugar models delete NAME_OR_ID
  # Undeploys and deletes a model.

os-sugar models status NAME_OR_ID
  # Reports deployment status of a model.
```

**Opinion:** This is the second most compelling use case. ML model registration is
configuration-heavy and stateful — it is exactly the kind of operation that benefits from a
CLI with clear progress feedback and idempotent semantics. Wrapping the polling loop and
lifecycle in a command-line tool is a genuine improvement over scripting it by hand.

### Document operations

```
os-sugar index index-jsonl INDEX FILE --id-field FIELD
  # Bulk-indexes a JSONL file into an index using the Sugar API.
  # Low ceremony; useful for one-off data loads.

os-sugar index count INDEX
  # Prints the document count. Useful in scripts and post-load verification.

os-sugar index clear INDEX [--force]
  # Deletes all documents. Requires --force.
```

**Opinion:** `index-jsonl` and `count` are solid. `clear` is occasionally useful in dev/staging
teardown scripts. These are low-cost to implement and fill a genuine gap — the Dashboard has no
bulk-load-from-file capability.

### Text analysis

```
os-sugar index analyze INDEX --analyzer ANALYZER TEXT
  # Runs the analyzer against TEXT and prints the resulting tokens.
  # Useful when tuning analyzers; instant feedback loop.

os-sugar index analyze-field INDEX --field FIELD TEXT
  # Same, but derives the analyzer from the field's mapping.
```

**Opinion:** These are genuinely useful for analyzer development and debugging. Running
`analyze` from the command line is faster and more convenient than curl or the Dashboard's
Dev Tools console when you are iterating on an analyzer configuration.

### Ingest pipeline management

```
os-sugar pipelines list
  # Lists ingest pipelines.

os-sugar pipelines create-embedding NAME --model MODEL --field-map src:target [...]
  # Creates a text-embedding pipeline.

os-sugar pipelines delete NAME
  # Deletes a pipeline.
```

**Opinion:** Pipeline creation is closely coupled to ML model management and has similar
operational semantics — it makes sense to include it for completeness. `list` and `delete`
are also useful for housekeeping.

---

## What to Deliberately Exclude

**Search and querying.** There are already good tools for this (`curl`, the OpenSearch
Dashboard Dev Tools, and dedicated query clients). Adding `os-sugar search INDEX --query '{...}'`
provides no advantage over `curl` and would require a JSON DSL design that is outside the gem's
scope.

**Settings and mappings inspection.** `GET /my_index/_settings` and `GET /my_index/_mappings`
are one-liner `curl` commands. A CLI wrapper adds nothing. Developers who want this output in a
readable format are better served by the Dashboard's index management pages.

**Cluster monitoring.** Health, shard allocation, node stats — all of this is handled better
by Grafana dashboards, the OpenSearch Dashboard, or dedicated monitoring tools. A CLI equivalent
would be immediately outdated.

**Schema management (applying mappings/settings from files).** This is genuinely useful
(`os-sugar index apply-settings INDEX settings.json`) but overlaps heavily with infrastructure-as-
code tools (Terraform OpenSearch provider, ansible roles). It may be worth adding later if
there is demonstrated demand, but it is not a day-one priority.

---

## On a TUI (TTY Toolkit)

**Not recommended.**

A TUI built on the `tty` gem family would give the CLI interactive menus, spinners, progress
bars, and formatted table output. Some of this is appealing — the model registration polling
loop would benefit from a progress indicator, and `models list` output in a nice table is
genuinely nicer to read.

The problem is scope and maintenance. The `tty` ecosystem (tty-prompt, tty-table, tty-spinner,
tty-color, etc.) is a significant dependency footprint and requires active maintenance as the
gem evolves. TUI components also tend to interact badly with CI/CD environments, piped output,
and non-interactive terminals — exactly the use cases where this CLI is most valuable.

The practical alternative is simpler: use `tty-spinner` for the model registration polling loop
(one gem, one use case, well-isolated) and plain text output everywhere else. Tabular output
can be produced with `format` and `ljust` without any gem dependency. The Dashboard handles the
visual layer for interactive exploration.

Anyone who wants a REPL with rich interactivity can load the gem in `pry` or `irb` and has the
full Ruby object model available.

---

## Implementation Notes

### Framework: `dry-cli`

`dry-cli` is the right choice. It provides:
- Subcommand routing (`os-sugar index create`, `os-sugar models list`)
- Typed argument and option definitions with descriptions and defaults
- Auto-generated `--help` at every level
- Clean separation between command definitions and implementation

The commands themselves are thin wrappers over the Sugar API. Each command class initialises a
`Client`, calls the appropriate Sugar method, and formats output. Error handling is straightforward:
rescue `OpenSearch::Sugar::Error` and `OpenSearch::Transport::Transport::Error`, print a message to
stderr, exit non-zero.

### Distribution

The CLI lives in a separate gem, `opensearch-sugar-cli`, that depends on `opensearch-sugar`.
This keeps the core library free of CLI dependencies (`dry-cli`, `tty-spinner` if used) and
allows the CLI to be versioned and distributed independently. The `opensearch-sugar` gem stays
focused on its Ruby API.

### Environment and configuration

All connection parameters are read from `OPENSEARCH_URL`, `OPENSEARCH_USER`, and
`OPENSEARCH_PASSWORD`, consistent with the existing Sugar defaults. A `--config FILE`
option pointing to a YAML or `.env` file would be a useful addition for multi-cluster workflows.
