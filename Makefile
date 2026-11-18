LUA_FILES := $(shell find lua plugin tests -name '*.lua')
NVIM_BIN ?= nvim
WIN_NVIM ?= /home/immortal/Projects/lib/win.nvim
ANIMATE_NVIM ?= /home/immortal/Projects/lib/animate.nvim

.PHONY: fmt fmt-check lint check test

fmt:
	stylua $(LUA_FILES)

fmt-check:
	stylua --check $(LUA_FILES)

lint:
	selene $(LUA_FILES)

check: fmt-check lint test

test:
	WIN_NVIM='$(WIN_NVIM)' ANIMATE_NVIM='$(ANIMATE_NVIM)' $(NVIM_BIN) --headless -u NONE --cmd 'set runtimepath+=.' -c 'luafile tests/smoke.lua'
