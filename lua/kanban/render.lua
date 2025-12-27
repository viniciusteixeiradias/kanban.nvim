local M = {}

local config = require("kanban.config")
local state = require("kanban.state")

local ns_id = vim.api.nvim_create_namespace("kanban_nvim")

M.win = nil
M.buf = nil

local function setup_highlights()
  vim.api.nvim_set_hl(0, "KanbanColumnHeader", { bold = true, fg = "#888888" })
  vim.api.nvim_set_hl(0, "KanbanColumnHeaderActive", { bold = true, fg = "#ffffff", bg = "#3a3a3a" })
  vim.api.nvim_set_hl(0, "KanbanTask", { default = true })
  vim.api.nvim_set_hl(0, "KanbanTaskActive", { fg = "#000000", bg = "#7dd3fc", bold = true })
  vim.api.nvim_set_hl(0, "KanbanTaskDone", { strikethrough = true, fg = "#666666" })
  vim.api.nvim_set_hl(0, "KanbanSeparator", { fg = "#444444" })
end

local function calculate_column_width(win_width, num_columns)
  if num_columns == 0 then return win_width end
  local available = win_width - (num_columns - 1)
  return math.floor(available / num_columns)
end

local function fit_width(str, width)
  local str_width = vim.fn.strdisplaywidth(str)
  if str_width > width then
    return vim.fn.strcharpart(str, 0, width - 1) .. "…"
  else
    return str .. string.rep(" ", width - str_width)
  end
end

local function render_row(row_idx, col_width, separator)
  local board = state.board
  if not board then return "", {} end

  local parts = {}
  local highlights = {}
  local current_pos = 0

  for col_idx, column in ipairs(board.columns) do
    local cell_text = ""
    local cell_hl = nil
    local is_current_col = col_idx == board.cursor.col

    if row_idx == 1 then
      cell_text = "## " .. column.name
      cell_hl = is_current_col and "KanbanColumnHeaderActive" or "KanbanColumnHeader"
    else
      local task_idx = row_idx - 1
      if task_idx <= #column.tasks then
        local task = column.tasks[task_idx]
        local checkbox = task.checked and "[x]" or "[ ]"
        local task_text = task.text:gsub("^%[[x ]%]%s*", "")
        cell_text = checkbox .. " " .. task_text

        local is_current_task = is_current_col and task_idx == board.cursor.row
        if is_current_task then
          cell_hl = "KanbanTaskActive"
        elseif task.checked then
          cell_hl = "KanbanTaskDone"
        else
          cell_hl = "KanbanTask"
        end
      end
    end

    local fitted = fit_width(cell_text, col_width)
    table.insert(parts, fitted)

    if cell_hl then
      table.insert(highlights, {
        col_start = current_pos,
        col_end = current_pos + #fitted,
        hl_group = cell_hl,
      })
    end

    current_pos = current_pos + #fitted

    if col_idx < #board.columns then
      table.insert(parts, separator)
      table.insert(highlights, {
        col_start = current_pos,
        col_end = current_pos + #separator,
        hl_group = "KanbanSeparator",
      })
      current_pos = current_pos + #separator
    end
  end

  return table.concat(parts), highlights
end

local function get_max_tasks()
  local board = state.board
  if not board then return 0 end

  local max = 0
  for _, column in ipairs(board.columns) do
    max = math.max(max, #column.tasks)
  end
  return max
end

local function create_window()
  local cfg = config.get().window

  local width = math.floor(vim.o.columns * cfg.width)
  local height = math.floor(vim.o.lines * cfg.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = cfg.border,
    title = " Kanban ",
    title_pos = "center",
    footer = " h/l:cols  j/k:tasks  H/L:move  a:add  d:del  x:toggle  e:edit  ?:help  q:quit ",
    footer_pos = "center",
  })

  vim.api.nvim_set_option_value("cursorline", false, { win = win })

  return buf, win
end

function M.render()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end

  local board = state.board
  if not board or #board.columns == 0 then
    return
  end

  local win_width = vim.api.nvim_win_get_width(M.win)
  local col_width = calculate_column_width(win_width, #board.columns)
  local separator = "│"

  local lines = {}
  local all_highlights = {}
  local max_tasks = get_max_tasks()

  local total_rows = 1 + max_tasks
  for row_idx = 1, total_rows do
    local line, highlights = render_row(row_idx, col_width, separator)
    table.insert(lines, line)
    all_highlights[row_idx] = highlights
  end

  local win_height = vim.api.nvim_win_get_height(M.win)
  while #lines < win_height - 2 do
    table.insert(lines, "")
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = M.buf })
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })

  vim.api.nvim_buf_clear_namespace(M.buf, ns_id, 0, -1)

  for row_idx, highlights in pairs(all_highlights) do
    for _, hl in ipairs(highlights) do
      vim.api.nvim_buf_add_highlight(
        M.buf,
        ns_id,
        hl.hl_group,
        row_idx - 1,
        hl.col_start,
        hl.col_end
      )
    end
  end
end

function M.open()
  setup_highlights()
  M.buf, M.win = create_window()
  M.render()
  return true
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
end

function M.is_open()
  return M.win ~= nil and vim.api.nvim_win_is_valid(M.win)
end

return M
