.PHONY: all build install uninstall clean test format

NAME=fff
SRC=src/fff.cr
BUILD_DIR=bin

all: build

build:
	crystal build $(SRC) --release -o $(BUILD_DIR)/$(NAME)

debug:
	crystal build $(SRC) -o $(BUILD_DIR)/$(NAME)

install: build
	@mkdir -p $(DESTDIR)$(PREFIX)/bin
	@mkdir -p $(DESTDIR)$(MANDIR)/man1
	@mkdir -p $(DESTDIR)$(DOCDIR)
	@cp -p $(BUILD_DIR)/$(NAME) $(DESTDIR)$(PREFIX)/bin/$(NAME)
	@cp -p $(NAME).1 $(DESTDIR)$(MANDIR)/man1
	@cp -p README.md $(DESTDIR)$(DOCDIR)
	@chmod 755 $(DESTDIR)$(PREFIX)/bin/$(NAME)

uninstall:
	@rm -rf $(DESTDIR)$(PREFIX)/bin/$(NAME)
	@rm -rf $(DESTDIR)$(MANDIR)/man1/$(NAME).1
	@rm -rf $(DESTDIR)$(DOCDIR)

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(NAME)

test:
	crystal spec

format:
	crystal tool format

deps:
	shards install

run: build
	./$(BUILD_DIR)/$(NAME)

help:
	@echo "Available targets:"
	@echo "  build    - Build the project (default)"
	@echo "  debug    - Build without optimizations"
	@echo "  install  - Install to system"
	@echo "  uninstall- Remove from system"
	@echo "  clean    - Remove build artifacts"
	@echo "  test     - Run tests"
	@echo "  format   - Format source code"
	@echo "  deps     - Install dependencies"
	@echo "  run      - Build and run"