# Makefile for Forge project

.PHONY: coverage clean build test

# Run Forge coverage with a gas report for the Bolt contract
coverage:
	forge coverage --gas-report --match-contract Bolt

# Clean the build artifacts
clean:
	forge clean

# Build the project
build:
	forge build

# Run all tests
test:
	forge test

