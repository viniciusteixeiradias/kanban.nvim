local M = {}

function M.setup(buffer, actions)
  local opts = { buffer = buffer, nowait = true, silent = true }

  vim.keymap.set("n", "h", actions.cursor_left, opts)
  vim.keymap.set("n", "l", actions.cursor_right, opts)
  vim.keymap.set("n", "j", actions.cursor_down, opts)
  vim.keymap.set("n", "k", actions.cursor_up, opts)

  vim.keymap.set("n", "H", actions.move_task_left, opts)
  vim.keymap.set("n", "L", actions.move_task_right, opts)
  vim.keymap.set("n", "J", actions.move_task_down, opts)
  vim.keymap.set("n", "K", actions.move_task_up, opts)

  vim.keymap.set("n", "x", actions.toggle_checkbox, opts)
  vim.keymap.set("n", "a", actions.add_task, opts)
  vim.keymap.set("n", "d", actions.delete_task, opts)
  vim.keymap.set("n", "e", actions.edit_task, opts)

  vim.keymap.set("n", "?", actions.show_help, opts)
  vim.keymap.set("n", "q", M.close, opts)
  vim.keymap.set("n", "<Esc>", M.close, opts)
  vim.keymap.set("n", "r", M.refresh, opts)
end

return M
