if vim.fn.has("nvim-0.9.0") == 0 then
  error("kanban.nvim requires Neovim >= 0.9.0")
  return
end

if vim.g.loaded_kanban_nvim == 1 then
  return
end

vim.g.loaded_kanban_nvim = 1

vim.api.nvim_create_user_command("Kanban", function(opts)
  local path = opts.args ~= "" and opts.args or nil
  require("kanban").open(path)
end, { nargs = "?", desc = "Open kanban board", complete = "file" })

vim.api.nvim_create_user_command("KanbanClose", function()
  require("kanban").close()
end, { desc = "Close kanban board" })

vim.api.nvim_create_user_command("KanbanToggle", function()
  require("kanban").toggle()
end, { desc = "Toggle kanban board" })
