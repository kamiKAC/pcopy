GO=$(shell which go)
VERSION := $(shell git describe --tag)

.PHONY:

help:
	@echo "Typical commands:"
	@echo "  make check                       - Run all tests, vetting/formatting checks and linters"
	@echo "  make fmt build-snapshot install  - Build latest and install to local system"
	@echo
	@echo "Test/check:"
	@echo "  make test                        - Run tests"
	@echo "  make coverage                    - Run tests and show coverage"
	@echo "  make coverage-html               - Run tests and show coverage (as HTML)"
	@echo "  make coverage-upload             - Upload coverage results to codecov.io"
	@echo
	@echo "Lint/format:"
	@echo "  make fmt                         - Run 'go fmt'"
	@echo "  make fmt-check                   - Run 'go fmt', but don't change anything"
	@echo "  make vet                         - Run 'go vet'"
	@echo "  make lint                        - Run 'golint'"
	@echo "  make staticcheck                 - Run 'staticcheck'"
	@echo
	@echo "Build:"
	@echo "  make build                       - Build"
	@echo "  make build-snapshot              - Build snapshot"
	@echo "  make build-simple                - Build (using go build, without goreleaser)"
	@echo "  make clean                       - Clean build folder"
	@echo
	@echo "Releasing (requires goreleaser):"
	@echo "  make release                     - Create a release"
	@echo "  make release-snapshot            - Create a test release"
	@echo
	@echo "Install locally (requires sudo):"
	@echo "  make install                     - Copy binary from dist/ to /usr/bin"
	@echo "  make install-deb                 - Install .deb from dist/"
	@echo "  make install-lint                - Install golint"


# Test/check targets

check: test fmt-check vet lint staticcheck

test: .PHONY
	$(GO) test ./...

coverage:
	mkdir -p build/coverage
	$(GO) test -race -coverprofile=build/coverage/coverage.txt -covermode=atomic ./...
	$(GO) tool cover -func build/coverage/coverage.txt

coverage-html:
	mkdir -p build/coverage
	$(GO) test -race -coverprofile=build/coverage/coverage.txt -covermode=atomic ./...
	$(GO) tool cover -html build/coverage/coverage.txt

coverage-upload:
	cd build/coverage && (curl -s https://codecov.io/bash | bash)

# Lint/formatting targets

fmt:
	$(GO) fmt ./...

fmt-check:
	test -z $(shell gofmt -l .)

vet:
	$(GO) vet ./...

lint:
	which golint || $(GO) install golang.org/x/lint/golint@latest
	$(GO) list ./... | grep -v /vendor/ | xargs -L1 golint -set_exit_status

staticcheck: .PHONY
	rm -rf build/staticcheck
	which staticcheck || $(GO) install honnef.co/go/tools/cmd/staticcheck@latest
	mkdir -p build/staticcheck
	ln -s "$(GO)" build/staticcheck/go
	PATH="$(PWD)/build/staticcheck:$(PATH)" staticcheck ./...
	rm -rf build/staticcheck

# Building targets

build: .PHONY
	goreleaser build --clean

build-snapshot:
	goreleaser build --snapshot --clean

build-simple: clean
	mkdir -p dist/pcopy_linux_amd64
	$(GO) build \
		-o dist/pcopy_linux_amd64/pcopy \
		-ldflags \
		"-s -w -X main.version=$(VERSION) -X main.commit=$(shell git rev-parse --short HEAD) -X main.date=$(shell date +%s)"

clean: .PHONY
	rm -rf dist build


# Releasing targets

release:
	goreleaser release --clean

release-snapshot:
	goreleaser release --snapshot --skip-publish --clean


# Installing targets

install:
	sudo rm -f /usr/bin/pcopy /usr/bin/pcp /usr/bin/ppaste
	sudo cp -a dist/pcopy_linux_amd64/pcopy /usr/bin/pcopy
	sudo ln -s /usr/bin/pcopy /usr/bin/pcp
	sudo ln -s /usr/bin/pcopy /usr/bin/ppaste

install-deb:
	sudo systemctl stop pcopy || true
	sudo apt-get purge pcopy || true
	sudo dpkg -i dist/*.deb
