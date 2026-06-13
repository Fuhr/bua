APP = build/Bua.app
BIN = .build/arm64-apple-macosx/release/Bua

.PHONY: build run probe icon clean

build:
	swift build -c release --arch arm64
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/Bua
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --sign $${CODESIGN_ID:--} $(APP)

# Regenerate the app icon from the rendered full-bloom lotus (run after
# editing Icon.swift), then re-slice into Resources/AppIcon.icns.
icon:
	swift build -c release --arch arm64
	$(BIN) --icon build/bua-icon.png
	rm -rf build/AppIcon.iconset && mkdir -p build/AppIcon.iconset
	sips -z 16 16   build/bua-icon.png --out build/AppIcon.iconset/icon_16x16.png
	sips -z 32 32   build/bua-icon.png --out build/AppIcon.iconset/icon_16x16@2x.png
	sips -z 32 32   build/bua-icon.png --out build/AppIcon.iconset/icon_32x32.png
	sips -z 64 64   build/bua-icon.png --out build/AppIcon.iconset/icon_32x32@2x.png
	sips -z 128 128 build/bua-icon.png --out build/AppIcon.iconset/icon_128x128.png
	sips -z 256 256 build/bua-icon.png --out build/AppIcon.iconset/icon_128x128@2x.png
	sips -z 256 256 build/bua-icon.png --out build/AppIcon.iconset/icon_256x256.png
	sips -z 512 512 build/bua-icon.png --out build/AppIcon.iconset/icon_256x256@2x.png
	sips -z 512 512 build/bua-icon.png --out build/AppIcon.iconset/icon_512x512.png
	cp build/bua-icon.png build/AppIcon.iconset/icon_512x512@2x.png
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns

run: build
	@pkill -x Bua 2>/dev/null || true
	open $(APP)

probe:
	swift build -c release --arch arm64
	$(BIN) --probe

clean:
	rm -rf .build build
