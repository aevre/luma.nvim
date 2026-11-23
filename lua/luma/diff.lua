local Win = require("win")

---@class luma.RewriteRange: luma.SelectionRange
---@field changedtick integer

local M = {}

---@param text string
---@return string
local function strip_fence(text)
  local fenced = text:match("^%s*```[^\n]*\n(.-)\n```%s*$")
  return fenced or text
end

---@param selection luma.RewriteRange
---@return boolean
local function valid_range(selection)
  local lines = vim.api.nvim_buf_get_lines(selection.bufnr, 0, -1, false)
  local start_line = selection.start_line
  local end_line = selection.end_line
  if start_line < 1 or end_line < start_line or end_line > #lines then
    return false
  end
  local start_length = #lines[start_line]
  local end_length = #lines[end_line]
  return selection.start_col >= 1
    and selection.start_col - 1 <= start_length
    and selection.end_col >= 0
    and selection.end_col <= end_length
end

---Preview a rewrite and apply it only if the source buffer and byte range are unchanged.
---@param source string
---@param proposed string
---@param selection luma.RewriteRange
function M.show(source, proposed, selection)
  proposed = strip_fence(proposed)
  local closed = false
  local left
  local right

  -- Either linked window may close first, so cleanup must be idempotent.
  local function close()
    if closed then
      return
    end
    closed = true
    for _, panel in ipairs({ left, right }) do
      if panel and panel:valid() then
        vim.api.nvim_win_call(panel.win, function()
          vim.cmd("diffoff")
        end)
      end
      if panel then
        panel:destroy()
      end
    end
  end

  local function accept()
    if not vim.api.nvim_buf_is_valid(selection.bufnr) then
      vim.notify("luma: source buffer no longer exists", vim.log.levels.ERROR)
      close()
      return
    end
    if vim.api.nvim_buf_get_changedtick(selection.bufnr) ~= selection.changedtick then
      vim.notify("luma: source changed while rewrite was running", vim.log.levels.ERROR)
      return
    end
    if not valid_range(selection) then
      vim.notify("luma: selected range is no longer valid", vim.log.levels.ERROR)
      return
    end
    local ok, err = pcall(
      vim.api.nvim_buf_set_text,
      selection.bufnr,
      selection.start_line - 1,
      selection.start_col - 1,
      selection.end_line - 1,
      selection.end_col,
      vim.split(proposed, "\n", { plain = true })
    )
    if not ok then
      vim.notify("luma: cannot apply rewrite: " .. tostring(err), vim.log.levels.ERROR)
      close()
      return
    end
    close()
  end

  local keys = {
    y = {
      function()
        accept()
      end,
      desc = "Accept rewrite",
    },
    n = {
      function()
        close()
      end,
      desc = "Reject rewrite",
    },
    q = {
      function()
        close()
      end,
      desc = "Close diff",
    },
    ["<Esc>"] = {
      function()
        close()
      end,
      desc = "Close diff",
    },
  }
  local common = {
    position = "float",
    width = 0.44,
    height = 0.75,
    border = "rounded",
    ft = vim.bo[selection.bufnr].filetype,
    bo = {
      modifiable = false,
      buftype = "nofile",
      bufhidden = "wipe",
    },
    wo = {
      number = true,
      wrap = false,
      winhighlight = "Normal:LumaNormal,NormalNC:LumaNormalNC,FloatBorder:LumaBorder,FloatTitle:LumaTitle,FloatFooter:LumaFooter,WinSeparator:LumaSeparator",
    },
    keys = keys,
    footer_keys = { "y", "n" },
  }
  left = Win(vim.tbl_deep_extend("force", common, {
    title = " Original ",
    col = 0.04,
    enter = false,
    text = vim.split(source, "\n", { plain = true }),
  }))
  right = Win(vim.tbl_deep_extend("force", common, {
    title = " Rewrite ",
    col = 0.52,
    enter = true,
    text = vim.split(proposed, "\n", { plain = true }),
  }))
  for _, panel in ipairs({ left, right }) do
    vim.api.nvim_win_call(panel.win, function()
      vim.cmd("diffthis")
    end)
  end
end

return M
