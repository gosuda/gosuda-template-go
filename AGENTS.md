# AGENTS.md — gosuda Organization

Official AI agent coding guidelines for Go projects under [github.com/gosuda](https://github.com/gosuda).

---

## Formatting & Style

**Mandatory** — run before every commit:

```bash
gofmt -w .
goimports -w .
```

Import ordering: **stdlib → external → internal** (separated by blank lines):

```go
import (
    "context"
    "fmt"
    "net/http"

    "github.com/go-chi/chi/v5"

    "github.com/gosuda/portal/internal/config"
)
```

**Naming:**
- Packages: lowercase, single word (`httpwrap`, not `http_wrap`)
- Interfaces: behavior verbs (`Reader`, `Handler`), not data descriptions
- Errors: `Err` prefix for sentinels (`ErrNotFound`), `Error` suffix for types
- Context: always first parameter — `func Do(ctx context.Context, ...)`

---

## Static Analysis & Linters

| Tool | Command |
|------|---------|
| Built-in vet | `go vet ./...` |
| golangci-lint v2 | `golangci-lint run` |
| Race detector | `go test -race ./...` |

Full linter configuration: **[`.golangci.yml`](.golangci.yml)** (committed to this repo).

Linter tiers enabled:

- **Correctness** — `govet`, `errcheck`, `staticcheck`, `unused`, `gosec`, `errorlint`, `nilerr`, `copyloopvar`, `bodyclose`, `sqlclosecheck`, `rowserrcheck`, `durationcheck`, `makezero`, `noctx`
- **Quality** — `gocritic` (all tags), `revive`, `unconvert`, `unparam`, `wastedassign`, `misspell`, `whitespace`, `godot`, `goconst`, `dupword`, `usestdlibvars`, `testifylint`, `testableexamples`, `tparallel`, `usetesting`
- **Concurrency safety** — `gochecknoglobals`, `gochecknoinits`, `containedctx`
- **Performance & modernization** — `prealloc`, `intrange`, `modernize`

---

## Error Handling

1. **Wrap errors** with `%w` — always add call-site context:
   ```go
   return fmt.Errorf("userRepo.FindByID: %w", err)
   ```

2. **Sentinel errors** per package:
   ```go
   var (
       ErrNotFound     = errors.New("user: not found")
       ErrUnauthorized = errors.New("user: unauthorized")
   )
   ```

3. **Never ignore errors** silently. `_ = fn()` only for functions in `errcheck.exclude-functions`.

4. **Fail fast** — return immediately on error; no state accumulation after failure.

5. **Check with `errors.Is` / `errors.As`** — never string-match `err.Error()`.

```go
// BAD
result, _ := doSomething()
return err                          // unwrapped, loses context
if err.Error() == "not found" {}    // fragile string match

// GOOD
return fmt.Errorf("processOrder: %w", err)
if errors.Is(err, ErrNotFound) {}
```

---

## Context & Concurrency

Every public function doing I/O or blocking **must** take `context.Context` first:

```go
func (s *Service) GetUser(ctx context.Context, id string) (*User, error) {
    return s.repo.FindByID(ctx, id)
}
```

| Pattern | Primitive |
|---------|-----------|
| Parallel work | `errgroup.Group` |
| Bounded concurrency | Buffered channel + goroutines |
| Wait for N goroutines | `sync.WaitGroup` |
| Concurrent read/write | `sync.RWMutex` |
| Lock-free counters | `atomic.Int64` / `atomic.Uint64` |
| One-time init | `sync.Once` |

**Rules:**
- Goroutine creator owns its lifecycle (start, stop, error handling)
- Worker pools use buffered channels for backpressure
- No bare `go func()` — handle errors and panics
- No `sync.Mutex` in public APIs — encapsulate behind methods
- Prefer `errgroup` over `WaitGroup` when goroutines return errors:

```go
g, ctx := errgroup.WithContext(ctx)
for _, item := range items {
    g.Go(func() error {
        return process(ctx, item)
    })
}
if err := g.Wait(); err != nil {
    return fmt.Errorf("processAll: %w", err)
}
```

---

## Testing

```bash
go test -v -race -coverprofile=coverage.out ./...
```

- **Table-driven tests** as the default pattern
- **Race detection** (`-race`) mandatory in CI
- **Benchmarks** for hot paths: `func BenchmarkX(b *testing.B)`
- **testify** for assertions when stdlib `testing` is verbose

---

## CI/CD & Tooling

Real config files committed to this repo:

| File | Purpose |
|------|---------|
| [`.golangci.yml`](.golangci.yml) | golangci-lint v2 configuration |
| [`Makefile`](Makefile) | Build/lint/test targets |
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | GitHub Actions pipeline |

**Pre-commit:**

```bash
make all
# or manually:
gofmt -w . && goimports -w . && go vet ./... && golangci-lint run && go test -race ./...
```

**Module hygiene:** `go mod tidy` before every commit.

---

## Verbalized Sampling (AI Agents)

Before non-trivial changes, AI agents **must**:

1. **Sample 3–5 intent hypotheses** — rank by likelihood, note one weakness each
2. **Explore edge cases** — up to 3 standard, 5 for architectural changes
3. **Assess coupling** — structural (imports), temporal (co-changing files), semantic (shared concepts)
4. **Tidy first** — high coupling → extract/split/rename before changing; low → change directly
5. **Surface decisions** — ask the human when trade-offs exist; do exactly what is asked, no more
