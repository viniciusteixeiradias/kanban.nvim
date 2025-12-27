local M = {}

local state = require("kanban.state")
local render = require("kanban.render")
local config = require("kanban.config")
local utils = require("kanban.utils")

local function refresh_open_buffers(filepath)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      if buf_name == filepath then
        if not vim.bo[bufnr].modified then
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("edit!")
          end)
        end
        break
      end
    end
  end
end

local function write_to_file()
  local board = state.board
  if not board then return end

  local lines = {}

  if board.title then
    table.insert(lines, "# " .. board.title)
    table.insert(lines, "")
  end

  for col_idx, column in ipairs(board.columns) do
    if col_idx > 1 then
      table.insert(lines, "")
    end

    table.insert(lines, "## " .. column.name)

    for _, task in ipairs(column.tasks) do
      table.insert(lines, task.raw)
    end
  end

  table.insert(lines, "")

  if utils.write_file(board.filepath, table.concat(lines, "\n")) then
    if config.get().auto_refresh_buffers then
      refresh_open_buffers(board.filepath)
    end
  else
    utils.notify("Failed to write to " .. board.filepath, vim.log.levels.ERROR)
  end
end

local function refresh()
  render.render()
end

local function create_cursor_action(state_fn, direction)
  return function()
    state_fn(direction)
    refresh()
  end
end

M.cursor_left = create_cursor_action(state.move_cursor_horizontal, -1)
M.cursor_right = create_cursor_action(state.move_cursor_horizontal, 1)
M.cursor_up = create_cursor_action(state.move_cursor_vertical, -1)
M.cursor_down = create_cursor_action(state.move_cursor_vertical, 1)

local function create_move_task_action(state_fn, direction, message)
  return function()
    if state_fn(direction) then
      write_to_file()
      refresh()
      utils.notify(message)
    end
  end
end

M.move_task_left = create_move_task_action(state.move_task_horizontal, -1, "Task moved left")
M.move_task_right = create_move_task_action(state.move_task_horizontal, 1, "Task moved right")
M.move_task_up = create_move_task_action(state.move_task_vertical, -1, "Task moved up")
M.move_task_down = create_move_task_action(state.move_task_vertical, 1, "Task moved down")

local function find_target_column_index(target)
  local board = state.board
  if not board then return nil end

  local target_lower = target:lower()
  for idx, column in ipairs(board.columns) do
    if column.name:lower():match(target_lower) then
      return idx
    end
  end
  return nil
end

function M.toggle_checkbox()
  if state.toggle_current_task() then
    local task = state.get_current_task()
    local moved = false
    local target_column = config.get().on_complete_move_to

    if task and task.checked and target_column then
      local target_idx = find_target_column_index(target_column)
      local current_col_idx = state.board.cursor.col

      if not target_idx then
        utils.notify("Target column '" .. target_column .. "' not found", vim.log.levels.WARN)
      elseif target_idx ~= current_col_idx then
        local direction = target_idx - current_col_idx
        while state.board.cursor.col ~= target_idx do
          state.move_task_horizontal(direction > 0 and 1 or -1)
        end
        moved = true
      end
    end

    write_to_file()
    refresh()

    if task then
      if moved then
        utils.notify("Task completed and moved to " .. target_column)
      else
        local status = task.checked and "completed" or "uncompleted"
        utils.notify("Task " .. status)
      end
    end
  end
end

local function create_input_dialog(opts)
  local width = opts.width or 50
  local height = 1
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = opts.title,
    title_pos = "center",
  })

  local initial_text = opts.initial_text or ""
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { initial_text })
  vim.api.nvim_win_set_cursor(win, { 1, #initial_text })

  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    vim.cmd("stopinsert")
  end

  vim.keymap.set({ "n", "i" }, "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = lines[1] or ""
    close_window()
    if text ~= "" then
      opts.on_submit(text)
    end
  end, { buffer = buf, nowait = true })

  vim.keymap.set({ "n", "i" }, "<Esc>", close_window, { buffer = buf, nowait = true })

  vim.cmd("startinsert!")
  vim.api.nvim_win_set_cursor(win, { 1, #initial_text })
end

function M.add_task()
  local column = state.get_current_column()
  if not column then return end

  create_input_dialog({
    title = " Add Task to " .. column.name .. " ",
    on_submit = function(text)
      state.add_task(text)
      write_to_file()
      refresh()
      utils.notify("Task added")
    end,
  })
end

function M.delete_task()
  local task = state.get_current_task()
  if not task then return end

  local task_preview = task.text:sub(1, 30)
  if #task.text > 30 then
    task_preview = task_preview .. "..."
  end

  local choice = vim.fn.confirm(
    "Delete task: " .. task_preview .. "?",
    "&Yes\n&No",
    2
  )

  if choice == 1 then
    state.delete_current_task()
    write_to_file()
    refresh()
    utils.notify("Task deleted")
  end
end

function M.edit_task()
  local task = state.get_current_task()
  if not task then return end

  local current_text = task.text:gsub("^%[[x ]%]%s*", "")

  create_input_dialog({
    title = " Edit Task ",
    width = 60,
    initial_text = current_text,
    on_submit = function(text)
      state.update_current_task(text)
      write_to_file()
      refresh()
      utils.notify("Task updated")
    end,
  })
end

function M.show_help()
  local help_lines = {
    "Kanban Board Keybindings",
    "==========================================",
    "",
    "Navigation:",
    "  h / l     Move between columns",
    "  j / k     Move between tasks",
    "",
    "Task Actions:",
    "  H / L     Move task to prev/next column",
    "  J / K     Move task up/down in column",
    "  x         Toggle checkbox [x] / [ ]",
    "  a         Add new task",
    "  d         Delete task",
    "  e         Edit task",
    "",
    "General:",
    "  ?         Show this help",
    "  r         Refresh board",
    "  q / Esc   Close kanban board",
  }

  local width = 40
  local height = #help_lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Help ",
    title_pos = "center",
  })

  local function close_help()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local close_keys = { "<Esc>", "q", "?", "<CR>", "<Space>" }
  for _, key in ipairs(close_keys) do
    vim.keymap.set("n", key, close_help, { buffer = buf, nowait = true })
  end
end

return M
