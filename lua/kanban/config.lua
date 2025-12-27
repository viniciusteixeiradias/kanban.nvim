local M = {}

local defaults = {
  -- Path to the markdown file (nil = auto-detect in project root)
  file = {
    path = nil,
    name = "TODO.md",
    create_if_missing = true,
  },
  -- Default columns when creating a new file
  default_columns = { "Backlog", "In Progress", "Done" },
  -- Floating window settings
  window = {
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
  -- Auto-refresh open buffers when changes are made
  auto_refresh_buffers = true,
  -- Move task to "Done" column when checked
  move_on_complete = true,
  -- Keymap to open kanban (set to false to disable)
  keymap = "<leader>tk",
}

M._config = vim.deepcopy(defaults)

function M.setup(opts)
  M._config = vim.tbl_deep_extend("force", defaults, opts or {})
end

function M.get()
  return M._config
end

return M
