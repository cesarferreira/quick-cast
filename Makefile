INSTALL_DIR ?= /Applications

.PHONY: build run test package install clean
build:
	swift build
run: package
	open "dist/Quick Cast.app"
test:
	swift test
package:
	./scripts/package.sh
install: package
	@osascript -e 'if application id "dev.cesar.quickcast" is running then' \
		-e 'tell application id "dev.cesar.quickcast" to quit' -e 'end if'
	@mkdir -p "$(INSTALL_DIR)"
	@ditto "dist/Quick Cast.app" "$(INSTALL_DIR)/Quick Cast.app"
	@open "$(INSTALL_DIR)/Quick Cast.app"
clean:
	swift package clean
	rm -rf dist
