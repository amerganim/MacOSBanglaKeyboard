# Amader Bangla Keyboard for macOS — build with the Xcode Command Line Tools
# (no Xcode project, no paid developer account needed).
#
#   make            build build/AmaderBanglaKeyboard.app (universal arm64+x86_64)
#   make test       build + run the engine unit tests
#   make install    install into ~/Library/Input Methods and enable it
#   make uninstall  remove it again
#   make dist       build release zip + pkg into dist/

VERSION    ?= 1.0.0
APP_NAME   := Amader Bangla Keyboard
EXE        := AmaderBanglaKeyboard
BUNDLE_ID  := io.github.amerganim.inputmethod.AmaderBanglaKeyboard
BUILD      := build
APP        := $(BUILD)/$(EXE).app
ARCHS      ?= -arch arm64 -arch x86_64
MINOS      := -mmacosx-version-min=11.0
CXX        := clang++
CXXFLAGS   := -std=c++17 -O2 -Wall -Wextra -Wno-unused-parameter $(ARCHS) $(MINOS) -Iengine/include
OBJCFLAGS  := $(CXXFLAGS) -fobjc-arc -fmodules
FRAMEWORKS := -framework Cocoa -framework InputMethodKit -framework Carbon

ENGINE_SRC := engine/src/Transliterator.cpp engine/src/Suggest.cpp
MAC_SRC    := mac/main.mm mac/BKShared.mm mac/BKCandidatePanel.mm mac/BKInputController.mm
RESOURCES  := resources/dictionary.tsv resources/words.tsv resources/KEYMAP.html \
              resources/MenuIcon.tiff resources/AppIcon.icns

.PHONY: all app test harness install uninstall dist clean icons

all: app

app: $(APP)/Contents/MacOS/$(EXE)

$(APP)/Contents/MacOS/$(EXE): $(ENGINE_SRC) $(MAC_SRC) mac/*.h engine/include/bnphonetic/*.h mac/Info.plist $(RESOURCES) resources/en.lproj/InfoPlist.strings
	@rm -rf "$(APP)"
	@mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources/en.lproj"
	$(CXX) $(OBJCFLAGS) $(ENGINE_SRC) $(MAC_SRC) $(FRAMEWORKS) -o "$@"
	sed 's/__VERSION__/$(VERSION)/g' mac/Info.plist > "$(APP)/Contents/Info.plist"
	printf 'APPL????' > "$(APP)/Contents/PkgInfo"
	cp $(RESOURCES) "$(APP)/Contents/Resources/"
	cp resources/en.lproj/InfoPlist.strings "$(APP)/Contents/Resources/en.lproj/"
	cp LICENSE "$(APP)/Contents/Resources/"
	codesign --force --sign - --timestamp=none "$(APP)"
	@echo "Built $(APP)"

$(BUILD)/engine_tests: $(ENGINE_SRC) tests/test_transliterator.cpp
	@mkdir -p $(BUILD)
	$(CXX) -std=c++17 -O2 -Wall -Iengine/include $(ENGINE_SRC) tests/test_transliterator.cpp -o $@

test: $(BUILD)/engine_tests
	$(BUILD)/engine_tests

harness: $(ENGINE_SRC) harness/main.cpp
	@mkdir -p $(BUILD)
	$(CXX) -std=c++17 -O2 -Iengine/include $(ENGINE_SRC) harness/main.cpp -o $(BUILD)/bnphonetic_harness

install: app
	./scripts/install.sh --from-build "$(APP)"

uninstall:
	./scripts/uninstall.sh

dist: app
	./scripts/package.sh "$(VERSION)"

icons:
	swift scripts/make-icons.swift resources

clean:
	rm -rf $(BUILD) dist
