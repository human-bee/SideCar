.PHONY: test build run realtime-smoke

test:
	swift test

build:
	swift build

run:
	swift run SideCar

realtime-smoke:
	scripts/realtime-smoke.sh
