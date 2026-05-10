.PHONY: lint test install uninstall package

VERSION ?= $(shell cat VERSION 2>/dev/null || echo 0.1.0)
DIST_DIR = dist
DIST_FILE = $(DIST_DIR)/send-to-sftp-$(VERSION).tar.gz

lint:
	shellcheck bin/send-to-sftp $(shell find . -name '*.sh' -not -path './tests/tmp/*')

test:
	./tests/run.sh

install:
	./install.sh

uninstall:
	./install.sh --uninstall

package: $(DIST_FILE)

$(DIST_FILE):
	mkdir -p $(DIST_DIR)
	tar czf $(DIST_FILE) \
		bin/ lib/ integrations/ install.sh VERSION LICENSE README.md CHANGELOG.md CONTRIBUTING.md
