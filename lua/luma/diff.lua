local Win = require("win")

local M = {}

local function strip_fence(text)
  local fenced = text:match("^%s*```[^\n]*\n(.-)\n```%s*$")
  return fenced or text
end

function M.show(source, proposed, selection)
  proposed = strip_fence(proposed)
  local closed = false
  local left
  local right

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
    vim.api.nvim_buf_set_text(
      selection.bufnr,
      selection.start_line - 1,
      selection.start_col - 1,
      selection.end_line - 1,
      selection.end_col,
      vim.split(proposed, "\n", { plain = true })
    )
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
    bo = { modifiable = false, buftype = "nofile", bufhidden = "wipe" },
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
