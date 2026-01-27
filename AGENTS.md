# AGENTS.md — gosuda Organization

Official AI agent coding guidelines for Go 1.25+ projects under [github.com/gosuda](https://github.com/gosuda).

---

## Formatting & Style

**Mandatory** before every commit: `gofmt -w . && goimports -w .`

Import ordering: **stdlib → external → internal** (blank-line separated). Local prefix: `github.com/gosuda`.

**Naming:** packages lowercase single-word (`httpwrap`) · interfaces as behavior verbs (`Reader`, `Handler`) · errors `Err` prefix sentinels (`ErrNotFound`), `Error` suffix types · context always first param `func Do(ctx context.Context, ...)`

---

## Static Analysis & Linters

| Tool | Command |
|------|---------|
| Built-in vet | `go vet ./...` |
| golangci-lint v2 | `golangci-lint run` |
| Race detector | `go test -race ./...` |
| Vulnerability scan | `govulncheck ./...` |

Full configuration: **[`.golangci.yml`](.golangci.yml)**. Linter tiers:

- **Correctness** — `govet`, `errcheck`, `staticcheck`, `unused`, `gosec`, `errorlint`, `nilerr`, `copyloopvar`, `bodyclose`, `sqlclosecheck`, `rowserrcheck`, `durationcheck`, `makezero`, `noctx`
- **Quality** — `gocritic` (all tags), `revive`, `unconvert`, `unparam`, `wastedassign`, `misspell`, `whitespace`, `godot`, `goconst`, `dupword`, `usestdlibvars`, `testifylint`, `testableexamples`, `tparallel`, `usetesting`
- **Concurrency safety** — `gochecknoglobals`, `gochecknoinits`, `containedctx`
- **Performance & modernization** — `prealloc`, `intrange`, `modernize`, `fatcontext`, `perfsprint`, `reassign`, `spancheck`, `mirror`, `recvcheck`

---

## Error Handling

1. **Wrap with `%w`** — always add call-site context: `return fmt.Errorf("repo.Find: %w", err)`
2. **Sentinel errors** per package: `var ErrNotFound = errors.New("user: not found")`
3. **Multi-error** — use `errors.Join(err1, err2)` or `fmt.Errorf("op: %w and %w", e1, e2)`
4. **Never ignore errors** — `_ = fn()` only for `errcheck.exclude-functions`
5. **Fail fast** — return immediately on error; no state accumulation after failure
6. **Check with `errors.Is` / `errors.As`** — never string-match `err.Error()`

```go
// BAD: result, _ := doSomething()  |  return err  |  err.Error() == "x"
// GOOD:
return fmt.Errorf("processOrder: %w", err)
if errors.Is(err, ErrNotFound) {}
```

---

## Iterators (Go 1.23+)

Standard iterator signatures: `func(yield func() bool)` · `func(yield func(V) bool)` · `func(yield func(K, V) bool)`

**Rules:**
- **Always check yield return** — program panics if ignored on break
- **Avoid defer/recover** inside iterator bodies
- **Use stdlib**: `slices.All`, `slices.Backward`, `slices.Collect`, `maps.Keys`, `maps.Values`
- Range over integers: `for i := range n {}`

---

## Context & Concurrency

Every public I/O function **must** take `context.Context` first.

| Pattern | Primitive |
|---------|-----------|
| Parallel work | `errgroup.Group` |
| Bounded concurrency | Buffered channel + goroutines |
| Wait for N goroutines | `sync.WaitGroup` |
| Concurrent read/write | `sync.RWMutex` |
| Lock-free counters | `atomic.Int64` / `atomic.Uint64` |
| One-time init | `sync.Once` |

**Rules:** goroutine creator owns lifecycle · worker pools use buffered channels for backpressure · no bare `go func()` — handle errors and panics · no `sync.Mutex` in public APIs · prefer `errgroup` over `WaitGroup` when goroutines return errors

```go
g, ctx := errgroup.WithContext(ctx)
for _, item := range items {
    g.Go(func() error { return process(ctx, item) })
}
if err := g.Wait(); err != nil { return fmt.Errorf("processAll: %w", err) }
```

---

## Testing

```bash
go test -v -race -coverprofile=coverage.out ./...
```

- **Benchmarks (Go 1.24+):** use `for b.Loop() {}` — prevents compiler optimizations, excludes setup from timing
- **Test contexts (Go 1.24+):** use `ctx := t.Context()` — auto-canceled when test ends
- **Table-driven tests** as default pattern · **race detection** (`-race`) mandatory in CI
- **Fuzz testing:** `go test -fuzz=. -fuzztime=30s` — targets must be fast and deterministic
- **testify** for assertions when stdlib `testing` is verbose

---

## Security

- **Vulnerability scanning:** `govulncheck ./...` — run in CI and before releases
- **Module integrity:** `go mod verify` — validates checksums against go.sum
- **Supply chain:** always commit `go.sum` · audit deps with `go mod graph` · pin toolchain in go.mod
- **SBOM:** generate on release with `syft packages . -o cyclonedx-json > sbom.json`
- **Crypto:** Go 1.24+ includes FIPS 140-3, post-quantum X25519MLKEM768, `crypto/rand.Text()` for secure tokens

---

## Performance

- **PGO:** collect production CPU profile → place as `default.pgo` in main package → rebuild (2–14% improvement)
- **GOGC:** default 100; high-throughput `200-400`; memory-constrained use `GOMEMLIMIT` with `GOGC=off`
- **Object reuse:** `sync.Pool` for hot-path allocations · weak pointers (`weak.Make`) for cache-friendly patterns
- **Benchmarking:** `go test -bench=. -benchmem` · profile with `-cpuprofile`/`-memprofile`
- **Escape analysis:** `go build -gcflags='-m'` to verify heap allocations on hot paths

---

## Module Hygiene

- **Always commit** `go.mod` and `go.sum` — reproducibility and integrity
- **Never commit** `go.work` — local development only
- **Pin toolchain:** `toolchain go1.25.0` in go.mod
- **Tool directive (Go 1.24+):** `tool golang.org/x/tools/cmd/stringer` in go.mod
- **Pre-release:** `go mod tidy && go mod verify && govulncheck ./...`
- **Sandboxed I/O (Go 1.24+):** use `os.Root` for directory-scoped file operations

---

## CI/CD & Tooling

| File | Purpose |
|------|---------|
| [`.golangci.yml`](.golangci.yml) | golangci-lint v2 configuration |
| [`Makefile`](Makefile) | Build/lint/test/vuln targets |
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | GitHub Actions: test → lint → security → build |

**Pre-commit:** `make all` or `gofmt -w . && goimports -w . && go vet ./... && golangci-lint run && go test -race ./... && govulncheck ./...`

---

## Verbalized Sampling (AI Agents)

Before non-trivial changes, AI agents **must**:

1. **Sample 3–5 intent hypotheses** — rank by likelihood, note one weakness each
2. **Explore edge cases** — up to 3 standard, 5 for architectural changes
3. **Assess coupling** — structural (imports), temporal (co-changing files), semantic (shared concepts)
4. **Tidy first** — high coupling → extract/split/rename before changing; low → change directly
5. **Surface decisions** — ask the human when trade-offs exist; do exactly what is asked, no more
