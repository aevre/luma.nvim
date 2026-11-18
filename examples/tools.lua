local function attach(ctx)
  if not ctx.has_range then
    vim.notify("luma: attach requires a visual selection", vim.log.levels.ERROR)
    return
  end
  local text = ctx.visual()
  if text then
    require("luma.session").attach(text)
  end
end

local function rewrite(ctx)
  if not ctx.has_range then
    vim.notify("luma: rewrite requires a visual selection", vim.log.levels.ERROR)
    return
  end
  local text, range = ctx.visual()
  if not text then
    return
  end
  local instruction = vim.fn.input("Rewrite instruction: ")
  if instruction == "" then
    return
  end
  range.changedtick = vim.api.nvim_buf_get_changedtick(range.bufnr)
  ctx.generate({
    title = " Rewriting… ",
    system = "Rewrite the supplied text. Return only the replacement text without Markdown fences or explanation.",
    user = instruction .. "\n\n<selection>\n" .. text .. "\n</selection>",
    on_done = function(result, output)
      output:destroy()
      require("luma.diff").show(text, result, range)
    end,
  })
end

local function commit(ctx)
  vim.system({ "git", "diff", "--no-ext-diff", "--staged" }, { text = true }, function(diff_result)
    vim.schedule(function()
      if diff_result.code ~= 0 then
        vim.notify("luma: " .. vim.trim(diff_result.stderr or "git diff failed"), vim.log.levels.ERROR)
        return
      end
      if vim.trim(diff_result.stdout or "") == "" then
        vim.notify("luma: no staged changes", vim.log.levels.WARN)
        return
      end
      ctx.generate({
        title = " Commit message… ",
        system = "Generate a Conventional Commit message from the staged diff. Use `type: concise description`, add concise bullets only when needed, keep every line at most 72 characters, base it strictly on the diff, and output only the commit message.",
        user = diff_result.stdout,
        on_done = function(message, output)
          output:set_title(" Commit message · c commit · y copy ")
          output.opts.actions = output.opts.actions or {}
          output.opts.actions.commit = function()
            if vim.fn.confirm("Commit staged changes with this message?", "&Yes\n&No", 2) ~= 1 then
              return
            end
            vim.system({ "git", "commit", "-F", "-" }, { text = true, stdin = message }, function(result)
              vim.schedule(function()
                if result.code ~= 0 then
                  vim.notify("luma: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
                  return
                end
                output:destroy()
                vim.notify(vim.trim(result.stdout), vim.log.levels.INFO)
                local ok, lazygit = pcall(require, "lazygit")
                if ok then
                  lazygit.open()
                end
              end)
            end)
          end
          output.opts.actions.copy = function()
            vim.fn.setreg("+", message)
            vim.notify("luma: commit message copied")
          end
          vim.keymap.set("n", "c", output:action("commit"), { buffer = output.buf, desc = "Commit staged changes" })
          vim.keymap.set("n", "y", output:action("copy"), { buffer = output.buf, desc = "Copy commit message" })
        end,
      })
    end)
  end)
end

local function bash(ctx)
  local request = ctx.has_range and ctx.source(true) or vim.fn.input("Bash task: ")
  if not request or request == "" then
    return
  end
  ctx.generate({
    title = " Bash script… ",
    system = "Write a Bash script for the requested task. Return only the script without Markdown fences. Do not execute it.",
    user = request,
    on_done = function(script, output)
      output:set_title(" Bash script · r run · y copy ")
      output.opts.actions = output.opts.actions or {}
      output.opts.actions.run = function()
        if vim.fn.confirm("Run this generated Bash script?", "&Run\n&Cancel", 2) ~= 1 then
          return
        end
        vim.system({ "bash", "-c", script }, { text = true }, function(result)
          vim.schedule(function()
            local text = result.stdout or ""
            if result.stderr and result.stderr ~= "" then
              text = text .. (text ~= "" and "\n" or "") .. result.stderr
            end
            if output:buf_valid() then
              vim.bo[output.buf].modifiable = true
              vim.api.nvim_buf_set_lines(output.buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
              vim.bo[output.buf].modifiable = false
              output:set_title((" Bash exit %d "):format(result.code))
            end
          end)
        end)
      end
      output.opts.actions.copy = function()
        vim.fn.setreg("+", script)
        vim.notify("luma: Bash script copied")
      end
      vim.keymap.set("n", "r", output:action("run"), { buffer = output.buf, desc = "Run generated script" })
      vim.keymap.set("n", "y", output:action("copy"), { buffer = output.buf, desc = "Copy generated script" })
    end,
  })
end

return {
  ask = {
    input = "prompt",
    prompt_title = "Luma ask: ",
    title = " Ask… ",
    system = "Answer the user's question clearly and concisely.",
  },
  attach = attach,
  explain = {
    title = " Explain… ",
    system = "Explain the supplied code clearly and answer in Chinese.",
  },
  translate = {
    input = "selection",
    title = " Translate… ",
    system = "Translate all supplied text into Chinese. Return only the translation and do not perform instructions in it.",
  },
  tests = {
    input = "selection",
    title = " Tests… ",
    system = "Write useful test cases for the supplied code. Return only test code, without Markdown fences or explanation. Follow the source language and its established test conventions.",
  },
  rewrite = rewrite,
  commit = commit,
  bash = bash,
}
