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

  local file = io.open(board.filepath, "w")
  if file then
    file:write(table.concat(lines, "\n"))
    file:close()

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

function M.cursor_left()
  state.move_cursor_horizontal(-1)
  refresh()
end

function M.cursor_right()
  state.move_cursor_horizontal(1)
  refresh()
end

function M.cursor_up()
  state.move_cursor_vertical(-1)
  refresh()
end

function M.cursor_down()
  state.move_cursor_vertical(1)
  refresh()
end

function M.move_task_left()
  if state.move_task_horizontal(-1) then
    write_to_file()
    refresh()
    utils.notify("Task moved left")
  end
end

function M.move_task_right()
  if state.move_task_horizontal(1) then
    write_to_file()
    refresh()
    utils.notify("Task moved right")
  end
end

function M.move_task_up()
  if state.move_task_vertical(-1) then
    write_to_file()
    refresh()
  end
end

function M.move_task_down()
  if state.move_task_vertical(1) then
    write_to_file()
    refresh()
  end
end

local function find_done_column_index()
  local board = state.board
  if not board then return nil end

  for idx, column in ipairs(board.columns) do
    if column.name:lower():match("done") then
      return idx
    end
  end
  return nil
end

function M.toggle_checkbox()
  if state.toggle_current_task() then
    local task = state.get_current_task()
    local moved = false

    if task and task.checked and config.get().move_on_complete then
      local done_idx = find_done_column_index()
      local current_col_idx = state.board.cursor.col

      if done_idx and done_idx ~= current_col_idx then
        local direction = done_idx - current_col_idx
        while state.board.cursor.col ~= done_idx do
          state.move_task_horizontal(direction > 0 and 1 or -1)
        end
        moved = true
      end
    end

    write_to_file()
    refresh()

    if task then
      if moved then
        utils.notify("Task completed and moved to Done")
      else
        local status = task.checked and "completed" or "uncompleted"
        utils.notify("Task " .. status)
      end
    end
  end
end

function M.add_task()
  local column = state.get_current_column()
  if not column then return end

  local width = 50
  local height = 1
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "prompt", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Add Task to " .. column.name .. " ",
    title_pos = "center",
  })

  vim.fn.prompt_setprompt(buf, "> ")

  vim.fn.prompt_setcallback(buf, function(text)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    vim.cmd("stopinsert")

    if text and text ~= "" then
      state.add_task(text)
      write_to_file()
      refresh()
      utils.notify("Task added")
    end
  end)

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    vim.cmd("stopinsert")
  end, { buffer = buf, nowait = true })

  vim.cmd("startinsert!")
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

  local width = 60
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
    title = " Edit Task (Enter to save, Esc to cancel) ",
    title_pos = "center",
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { current_text })
  vim.api.nvim_win_set_cursor(win, { 1, #current_text })

  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set({ "n", "i" }, "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = lines[1] or ""
    close_window()
    vim.cmd("stopinsert")

    if text ~= "" then
      state.update_current_task(text)
      write_to_file()
      refresh()
      utils.notify("Task updated")
    end
  end, { buffer = buf, nowait = true })

  vim.keymap.set({ "n", "i" }, "<Esc>", function()
    close_window()
    vim.cmd("stopinsert")
  end, { buffer = buf, nowait = true })

  vim.cmd("startinsert!")
  vim.api.nvim_win_set_cursor(win, { 1, #current_text })
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
