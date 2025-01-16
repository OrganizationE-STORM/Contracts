# Define the default target
.PHONY: all
all: build analyze

# Build target using forge
.PHONY: build
build:
	forge build

# Analyze target using aderyn
.PHONY: analyze
analyze:
	aderyn .

.PHONY: test
test:
	forge coverage --report lcov -vv

# Install dependencies (forge and aderyn)
.PHONY: install
install:
	curl -L https://foundry.paradigm.xyz | bash
	foundryup
	curl -L https://raw.githubusercontent.com/Cyfrin/aderyn/dev/cyfrinup/install | bash
	cyfrinup

# Clean target to remove build artifacts
.PHONY: clean
clean:
	forge clean

# Format target for code consistency
.PHONY: format
format:
	forge fmt
