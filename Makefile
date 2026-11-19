LUA_FILES := $(shell find lua plugin tests examples -name '*.lua')
NVIM_BIN ?= nvim
LUA_LS ?= lua-language-server
WIN_NVIM ?= ../win.nvim
ANIMATE_NVIM ?= ../animate.nvim

.PHONY: fmt fmt-check lint check test health

fmt:
	stylua $(LUA_FILES)

fmt-check:
	stylua --check $(LUA_FILES)

lint:
	selene $(LUA_FILES)
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
		animate=$$(realpath '$(ANIMATE_NVIM)/lua'); win=$$(realpath '$(WIN_NVIM)/lua'); \
		awk -v animate="$$animate" -v win="$$win" \
			'/VIMRUNTIME/ { sub(/"$$/, "\","); print; printf "    \"%s\",\n    \"%s\"\n", animate, win; next } { print }' \
			.luarc.json.example > "$$tmp/.luarc.json"; \
		$(LUA_LS) --check='$(CURDIR)' --checklevel=Warning --check_format=pretty \
		--configpath="$$tmp/.luarc.json" --logpath="$$tmp/log"

check: fmt-check lint test health

test:
	WIN_NVIM='$(WIN_NVIM)' ANIMATE_NVIM='$(ANIMATE_NVIM)' $(NVIM_BIN) --headless -u NONE --cmd 'set runtimepath+=.' -c 'luafile tests/smoke.lua'

health:
	$(NVIM_BIN) --headless -u NONE --cmd 'set runtimepath^=.,$(WIN_NVIM),$(ANIMATE_NVIM)' -c 'checkhealth luma' -c 'lua vim.wait(1000); assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("luma.nvim", 1, true))' -c 'qa!'
