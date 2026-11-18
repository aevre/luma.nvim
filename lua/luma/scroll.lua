local M = {}

function M.bottom(panel, immediate)
  if not panel or not panel:valid() then
    return
  end
  local line_count = vim.api.nvim_buf_line_count(panel.buf)
  local current = vim.api.nvim_win_get_cursor(panel.win)[1]
  local function move(line)
    if not panel:valid() then
      return
    end
    vim.api.nvim_win_call(panel.win, function()
      pcall(vim.api.nvim_win_set_cursor, panel.win, { math.max(1, math.min(line, line_count)), 0 })
      vim.cmd("normal! zb")
    end)
  end

  local animate = require("animate")
  if immediate or current == line_count or not animate.enabled({ name = "scroll", buf = panel.buf }) then
    move(line_count)
    return
  end
  animate(current, line_count, move, {
    id = "luma-scroll-" .. panel.id,
    duration = { step = 8, total = 120 },
    easing = "outQuad",
    int = true,
    buf = panel.buf,
  })
end

return M
