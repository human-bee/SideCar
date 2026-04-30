.PHONY: test build run app audit-share realtime-smoke

test:
	swift test

build:
	swift build

run:
	swift run SideCar

app:
	scripts/build-debug-app.sh

audit-share:
	scripts/audit-share-ready.sh

realtime-smoke:
	scripts/realtime-smoke.sh
