.PHONY: test build run app realtime-smoke

test:
	swift test

build:
	swift build

run:
	swift run SideCar

app:
	scripts/build-debug-app.sh

realtime-smoke:
	scripts/realtime-smoke.sh
