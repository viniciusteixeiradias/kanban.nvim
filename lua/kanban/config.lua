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
  -- Highlight colors
  highlights = {
    column_header = { bold = true, fg = "#888888" },
    column_header_active = { bold = true, fg = "#ffffff", bg = "#3a3a3a" },
    task = { default = true },
    task_active = { fg = "#000000", bg = "#7dd3fc", bold = true },
    task_done = { strikethrough = true, fg = "#666666" },
    separator = { fg = "#444444" },
  },
  -- Auto-refresh open buffers when changes are made
  auto_refresh_buffers = true,
  -- Target column when task is checked (case-insensitive match, nil to disable)
  on_complete_move_to = "Done",
}

M._config = vim.deepcopy(defaults)

function M.setup(opts)
  M._config = vim.tbl_deep_extend("force", defaults, opts or {})
end

function M.get()
  return M._config
end

return M
