local M = {}

--- The current board state, holds all data for the kanban view
--- @class BoardState
--- @field columns table[] List of columns, each with name and tasks
--- @field cursor { col: number, row: number } Current cursor position (1-indexed)
--- @field filepath string Path to the source markdown file
M.board = nil

--- Initializes the board state from parsed data
--- @param parsed table The parsed board from parser.lua
--- @param filepath string Path to the source file
function M.init(parsed, filepath)
  M.board = {
    columns = parsed.columns,
    cursor = { col = 1, row = 1 },
    filepath = filepath,
  }

  M.clamp_cursor()
end

--- Clears the current board state
function M.clear()
  M.board = nil
end

--- Gets the currently selected column
--- @return table|nil The current column or nil if no board
function M.get_current_column()
  if not M.board or #M.board.columns == 0 then
    return nil
  end

  return M.board.columns[M.board.cursor.col]
end

--- Gets the currently selected task
--- @return table|nil The current task or nil if no selection
function M.get_current_task()
  local column = M.get_current_column()

  if not column or #column.tasks == 0 then
    return nil
  end

  return column.tasks[M.board.cursor.row]
end

--- Ensures cursor stays within valid bounds
function M.clamp_cursor()
  if not M.board then return end

  local num_cols = #M.board.columns

  if num_cols == 0 then
    M.board.cursor = { col = 1, row = 1 }
    return
  end

  M.board.cursor.col = math.max(1, math.min(M.board.cursor.col, num_cols))

  local column = M.board.columns[M.board.cursor.col]
  local num_tasks = #column.tasks

  if num_tasks == 0 then
    M.board.cursor.row = 1
  else
    M.board.cursor.row = math.max(1, math.min(M.board.cursor.row, num_tasks))
  end
end

--- Moves cursor to the next/previous column
--- @param direction number -1 for left, 1 for right
function M.move_cursor_horizontal(direction)
  if not M.board then return end

  local new_col = M.board.cursor.col + direction

  if new_col >= 1 and new_col <= #M.board.columns then
    M.board.cursor.col = new_col
    M.clamp_cursor()
  end
end

--- Moves cursor to the next/previous task in current column
--- @param direction number -1 for up, 1 for down
function M.move_cursor_vertical(direction)
  if not M.board then return end

  local column = M.get_current_column()

  if not column then return end

  local new_row = M.board.cursor.row + direction

  if new_row >= 1 and new_row <= #column.tasks then
    M.board.cursor.row = new_row
  end
end

--- Moves the current task to an adjacent column
--- @param direction number -1 for left, 1 for right
--- @return boolean success Whether the move was successful
function M.move_task_horizontal(direction)
  if not M.board then return false end

  local from_col_idx = M.board.cursor.col
  local to_col_idx = from_col_idx + direction

  if to_col_idx < 1 or to_col_idx > #M.board.columns then
    return false
  end

  local from_column = M.board.columns[from_col_idx]
  local to_column = M.board.columns[to_col_idx]
  local task_idx = M.board.cursor.row

  if #from_column.tasks == 0 or task_idx > #from_column.tasks then
    return false
  end

  local task = table.remove(from_column.tasks, task_idx)
  table.insert(to_column.tasks, task)

  M.board.cursor.col = to_col_idx
  M.board.cursor.row = #to_column.tasks

  return true
end

--- Moves the current task up or down within its column
--- @param direction number -1 for up, 1 for down
--- @return boolean success Whether the move was successful
function M.move_task_vertical(direction)
  if not M.board then return false end

  local column = M.get_current_column()

  if not column or #column.tasks < 2 then
    return false
  end

  local current_idx = M.board.cursor.row
  local new_idx = current_idx + direction

  if new_idx < 1 or new_idx > #column.tasks then
    return false
  end

  column.tasks[current_idx], column.tasks[new_idx] =
      column.tasks[new_idx], column.tasks[current_idx]

  M.board.cursor.row = new_idx

  return true
end

--- Toggles the checkbox state of the current task
--- @return boolean success Whether the toggle was successful
function M.toggle_current_task()
  local task = M.get_current_task()

  if not task then return false end

  task.checked = not task.checked

  if task.checked then
    task.raw = task.raw:gsub("%[ %]", "[x]", 1)
    task.text = task.text:gsub("^%[ %]", "[x]")
  else
    task.raw = task.raw:gsub("%[x%]", "[ ]", 1)
    task.text = task.text:gsub("^%[x%]", "[ ]")
  end

  return true
end

--- Adds a new task to the current column
--- @param text string The task text
--- @return table|nil The newly created task
function M.add_task(text)
  local column = M.get_current_column()

  if not column then return nil end

  local task = {
    text = "[ ] " .. text,
    checked = false,
    raw = "- [ ] " .. text,
    line = nil,
  }

  local insert_idx = M.board.cursor.row + 1
  if #column.tasks == 0 then
    insert_idx = 1
  end

  table.insert(column.tasks, insert_idx, task)
  M.board.cursor.row = insert_idx

  return task
end

--- Deletes the current task
--- @return table|nil The deleted task, or nil if none
function M.delete_current_task()
  local column = M.get_current_column()

  if not column or #column.tasks == 0 then
    return nil
  end

  local task = table.remove(column.tasks, M.board.cursor.row)
  M.clamp_cursor()

  return task
end

--- Updates the text of the current task
--- @param new_text string The new task text
--- @return boolean success Whether the update was successful
function M.update_current_task(new_text)
  local task = M.get_current_task()

  if not task then return false end

  local prefix = task.checked and "[x] " or "[ ] "
  task.text = prefix .. new_text
  task.raw = "- " .. prefix .. new_text

  return true
end

return M
