.PHONY: fmt vet lint test build all

fmt:
	gofmt -w .
	goimports -w .

vet:
	go vet ./...

lint:
	golangci-lint run

test:
	go test -v -race -coverprofile=coverage.out ./...

build:
	go build ./...

all: fmt vet lint test build
