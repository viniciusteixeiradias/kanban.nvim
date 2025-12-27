local M = {}

local state_m = require("kanban.state")
local utils_m = require("kanban.utils")
local render_m = require("kanban.render")
local parser_m = require("kanban.parser")
local actions_m = require("kanban.actions")
local keymaps_m = require("kanban.keymaps")

local config_m = require("kanban.config")
local config = config_m.get()

M.setup = config_m.setup

-- TODO: Maybe move this to utils.lua
local function get_file_path()
  if config.file.path then
    return vim.fn.expand(config.file.path)
  end

  local root = utils_m.get_project_root()
  local candidates = { config.file.name, config.file.name:lower() }

  for _, name in ipairs(candidates) do
    local path = root .. "/" .. name
    if utils_m.path_exists(path) then
      return path
    end
  end

  return root .. "/" .. config.file.name
end

-- TODO: Maybe move this to utils.lua
local function write_default_content(filepath)
  local columns = config.default_columns or { "Backlog", "In Progress", "Done" }
  local lines = { "# Kanban Board", "" }

  for _, col_name in ipairs(columns) do
    table.insert(lines, "## " .. col_name)
    table.insert(lines, "")
  end

  local content = table.concat(lines, "\n")
  utils_m.ensure_parent_dir(filepath)
  utils_m.write_file(filepath, content)

  return content
end

function M.open(filepath)
  filepath = filepath or get_file_path()
  local path_exists = utils_m.path_exists(filepath)

  if not path_exists and not config.file.create_if_missing then
    utils_m.notify("File not found: " .. filepath, vim.log.levels.ERROR)
    return
  end

  local content = utils_m.read_file(filepath) or write_default_content(filepath)
  local parsed, err = parser_m.parse(content)

  if not parsed or err then
    utils_m.notify(err or "Failed to parse markdown", vim.log.levels.ERROR)
    return
  end

  if #parsed.columns == 0 then
    content = write_default_content(filepath)
    parsed = parser_m.parse(content)
  end

  state_m.init(parsed --[[@as table]], filepath)
  render_m.open(config, state_m.board)
  keymaps_m.setup(render_m.buf, actions_m)

  utils_m.notify("Kanban: " .. vim.fn.fnamemodify(filepath, ":~:."))
end

function M.close()
  render_m.close()
  state_m.clear()
end

function M.refresh()
  local filepath = state_m.board and state_m.board.filepath

  if not filepath then
    M.open()
    return
  end

  local cursor = state_m.board.cursor
  local content = utils_m.read_file(filepath)

  if not content then
    utils_m.notify("Cannot read " .. filepath, vim.log.levels.ERROR)
    return
  end

  local parsed, err = parser_m.parse(content)

  if not parsed or err then
    utils_m.notify(err or "Failed to parse markdown", vim.log.levels.ERROR)
    return
  end

  state_m.init(parsed, filepath)
  state_m.board.cursor = cursor
  state_m.clamp_cursor()

  render_m.render(state_m.board)
  utils_m.notify("Board refreshed")
end

--
-- function M.toggle()
--   if render.is_open() then
--     M.close()
--   else
--     M.open()
--   end
-- end

return M
