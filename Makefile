APP = build/Bua.app
BIN = .build/arm64-apple-macosx/release/Bua

.PHONY: build run probe clean

build:
	swift build -c release --arch arm64
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BIN) $(APP)/Contents/MacOS/Bua
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	codesign --force --sign $${CODESIGN_ID:--} $(APP)

run: build
	@pkill -x Bua 2>/dev/null || true
	open $(APP)

probe:
	swift build -c release --arch arm64
	$(BIN) --probe

clean:
	rm -rf .build build
