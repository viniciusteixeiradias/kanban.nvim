# kanban.nvim

A keyboard-centric Kanban board for Neovim that uses markdown files.

## Features

- **Markdown-based** - Uses `## Headings` as columns and `- [ ] items` as tasks
- **Keyboard-driven** - Navigate and manage tasks without leaving the keyboard
- **Compatible** - Works with Obsidian-style markdown files
- **Auto-sync** - Optionally refreshes open buffers when changes are made

## Requirements

- Neovim >= 0.9.0
- Tree-sitter markdown parser (optional, falls back to pattern matching)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "viniciusteixeiradias/kanban.nvim",
  config = function()
    require("kanban").setup()
  end,
}
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:Kanban [file]` | Open kanban board (optional file path) |
| `:KanbanClose` | Close kanban board |
| `:KanbanToggle` | Toggle kanban board |

### Default Keymaps

| Keymap | Action |
|--------|--------|
| `<leader>tk` | Open kanban board |

### Board Keybindings

| Key | Action |
|-----|--------|
| `h` / `l` | Move between columns |
| `j` / `k` | Move between tasks |
| `H` / `L` | Move task to prev/next column |
| `J` / `K` | Move task up/down in column |
| `x` | Toggle checkbox `[ ]` ↔ `[x]` |
| `a` | Add new task |
| `d` | Delete task |
| `e` | Edit task |
| `r` | Refresh board |
| `?` | Show help |
| `q` / `Esc` | Close board |

## Markdown Format

```markdown
## Backlog
- [ ] Task one
- [ ] Task two

## In Progress
- [ ] Current task

## Done
- [x] Completed task
```

## Configuration

```lua
require("kanban").setup({
  file = {
    path = nil,              -- Custom path (nil = auto-detect)
    name = "TODO.md",        -- Default filename
    create_if_missing = true,
  },
  default_columns = { "Backlog", "In Progress", "Done" },
  window = {
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
  highlights = {
    column_header = { bold = true, fg = "#888888" },
    column_header_active = { bold = true, fg = "#ffffff", bg = "#3a3a3a" },
    task = { default = true },
    task_active = { fg = "#000000", bg = "#7dd3fc", bold = true },
    task_done = { strikethrough = true, fg = "#666666" },
    separator = { fg = "#444444" },
  },
  auto_refresh_buffers = true,  -- Refresh open markdown buffers on changes
  on_complete_move_to = "Done", -- Target column when checked (nil to disable)
  keymap = "<leader>tk",        -- Set to false to disable
})
```

## License

MIT License. See [LICENSE](./LICENSE) file for details.
