local M = {}

local parser = require("kanban.parser")
local state = require("kanban.state")
local render = require("kanban.render")
local actions = require("kanban.actions")
local config = require("kanban.config")
local utils = require("kanban.utils")

local function setup_keymaps()
  local buf = render.buf
  if not buf then return end

  local opts = { buffer = buf, nowait = true, silent = true }

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

local function write_default_content(filepath)
  local columns = config.get().default_columns or { "Backlog", "In Progress", "Done" }
  local lines = { "# Kanban Board", "" }

  for _, col_name in ipairs(columns) do
    table.insert(lines, "## " .. col_name)
    table.insert(lines, "")
  end

  local content = table.concat(lines, "\n")
  utils.ensure_parent_dir(filepath)
  utils.write_file(filepath, content)

  return content
end

local function get_file_path()
  local cfg = config.get().file

  if cfg.path then
    return utils.expand_path(cfg.path)
  end

  local root = utils.get_project_root()
  local candidates = { cfg.name, cfg.name:lower() }

  for _, name in ipairs(candidates) do
    local path = root .. "/" .. name
    if utils.path_exists(path) then
      return path
    end
  end

  return root .. "/" .. cfg.name
end

function M.setup(opts)
  config.setup(opts)
end

function M.open(filepath)
  filepath = filepath or get_file_path()
  local path_exists = utils.path_exists(filepath)

  if not path_exists and not config.get().file.create_if_missing then
    utils.notify("File not found: " .. filepath, vim.log.levels.ERROR)
    return
  end

  local content = utils.read_file(filepath) or write_default_content(filepath)
  local parsed, err = parser.parse(content)

  if not parsed or err then
    utils.notify(err or "Failed to parse markdown", vim.log.levels.ERROR)
    return
  end

  if #parsed.columns == 0 then
    content = write_default_content(filepath)
    parsed, err = parser.parse(content)

    if not parsed then
      utils.notify(err or "Failed to parse default content", vim.log.levels.ERROR)
      return
    end
  end

  state.init(parsed, filepath)
  render.open()
  setup_keymaps()

  utils.notify("Kanban: " .. vim.fn.fnamemodify(filepath, ":~:."))
end

function M.close()
  render.close()
  state.clear()
end

function M.refresh()
  local filepath = state.board and state.board.filepath
  if not filepath then
    M.open()
    return
  end

  local cursor = state.board.cursor
  local content = utils.read_file(filepath)

  if not content then
    utils.notify("Cannot read " .. filepath, vim.log.levels.ERROR)
    return
  end

  local parsed, err = parser.parse(content)
  if not parsed then
    utils.notify(err or "Failed to parse markdown", vim.log.levels.ERROR)
    return
  end

  state.init(parsed, filepath)
  state.board.cursor = cursor
  state.clamp_cursor()

  render.render()
  utils.notify("Board refreshed")
end

function M.toggle()
  if render.is_open() then
    M.close()
  else
    M.open()
  end
end

return M
