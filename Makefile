LUA_FILES := $(shell find lua plugin tests examples -name '*.lua')
NVIM_BIN ?= nvim
LUA_LS ?= lua-language-server
WIN_NVIM ?= /home/immortal/Projects/lib/win.nvim
ANIMATE_NVIM ?= /home/immortal/Projects/lib/animate.nvim

.PHONY: fmt fmt-check lint check test

fmt:
	stylua $(LUA_FILES)

fmt-check:
	stylua --check $(LUA_FILES)

lint:
	selene $(LUA_FILES)
	@log=$$(mktemp -d); trap 'rm -rf "$$log"' EXIT; \
		$(LUA_LS) --check='$(CURDIR)' --checklevel=Warning --check_format=pretty \
		--configpath='$(CURDIR)/.luarc.json.example' --logpath="$$log"

check: fmt-check lint test

test:
	WIN_NVIM='$(WIN_NVIM)' ANIMATE_NVIM='$(ANIMATE_NVIM)' $(NVIM_BIN) --headless -u NONE --cmd 'set runtimepath+=.' -c 'luafile tests/smoke.lua'
