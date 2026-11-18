if vim.g.loaded_luma_nvim then
  return
end
vim.g.loaded_luma_nvim = true

if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("luma.nvim requires Neovim 0.10+", vim.log.levels.ERROR)
  return
end

require("luma")._bootstrap()
