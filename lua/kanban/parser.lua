local M = {}

--- Extracts text content from a Tree-sitter node
--- @param node userdata Tree-sitter node
--- @param source string The full source text
--- @return string The text content of the node
local function get_node_text(node, source)
  local start_row, start_col, end_row, end_col = node:range()
  local lines = vim.split(source, "\n")

  -- Single line node: extract substring directly
  if start_row == end_row then
    return lines[start_row + 1]:sub(start_col + 1, end_col)
  end

  -- Multi-line node: concatenate all lines
  local result = { lines[start_row + 1]:sub(start_col + 1) }
  for i = start_row + 2, end_row do
    table.insert(result, lines[i])
  end
  table.insert(result, lines[end_row + 1]:sub(1, end_col))
  return table.concat(result, "\n")
end

--- Parses a task line to extract checkbox state
--- @param text string The task text (without the leading "- ")
--- @return table Parsed task with text and checked state
local function parse_task_text(text)
  local checked = false
  local task_text = text

  -- Check for checkbox pattern: [x] or [ ]
  local checkbox_match = text:match("^%[([x ])%]%s*(.*)$")
  if checkbox_match then
    checked = text:match("^%[x%]") ~= nil
    task_text = text:match("^%[[x ]%]%s*(.*)$") or ""
  end

  return {
    text = task_text,
    checked = checked,
  }
end

--- Parses markdown content using Tree-sitter to extract kanban columns and tasks
--- Columns are H2 headings (## Column Name)
--- Tasks are list items under each heading
--- @param content string The markdown file content
--- @return table|nil Parsed board structure, or nil on error
--- @return string|nil Error message if parsing failed
function M.parse(content)
  -- Try to get the Tree-sitter markdown parser
  local ok, parser = pcall(vim.treesitter.get_string_parser, content, "markdown")
  if not ok then
    return M.parse_fallback(content)
  end

  local tree = parser:parse()[1]
  if not tree then
    return M.parse_fallback(content)
  end

  local root = tree:root()
  local lines = vim.split(content, "\n")
  local columns = {}

  -- Tree-sitter query to find all H2 headings (## Heading)
  -- Each H2 heading becomes a kanban column
  local query_str = [[
    (section
      (atx_heading
        (atx_h2_marker)
        heading_content: (_) @heading))
  ]]

  local query_ok, query = pcall(vim.treesitter.query.parse, "markdown", query_str)
  if not query_ok then
    return M.parse_fallback(content)
  end

  -- Iterate through all H2 headings found by the query
  for _, node in query:iter_captures(root, content, 0, -1) do
    local heading_text = vim.trim(get_node_text(node, content))
    -- The section node contains both the heading and its content (lists)
    local section = node:parent():parent()
    local tasks = {}

    if section then
      -- Find all list items within this section
      for child in section:iter_children() do
        if child:type() == "list" then
          for list_item in child:iter_children() do
            if list_item:type() == "list_item" then
              local item_row = list_item:range()
              local line = lines[item_row + 1]
              if line then
                -- Extract text after the list marker (-, *, +)
                local item_text = line:match("^%s*[%-*+]%s*(.*)$")
                if item_text then
                  local parsed = parse_task_text(item_text)
                  parsed.line = item_row + 1
                  parsed.raw = line
                  table.insert(tasks, parsed)
                end
              end
            end
          end
        end
      end
    end

    table.insert(columns, {
      name = heading_text,
      tasks = tasks,
    })
  end

  return { columns = columns }
end

--- Fallback parser using Lua patterns when Tree-sitter is unavailable
--- @param content string The markdown file content
--- @return table Parsed board structure
function M.parse_fallback(content)
  local lines = vim.split(content, "\n")
  local columns = {}
  local current_column = nil

  for i, line in ipairs(lines) do
    -- Check for H2 heading: ## Column Name
    local heading = line:match("^##%s+(.+)$")
    if heading then
      if current_column then
        table.insert(columns, current_column)
      end
      current_column = {
        name = vim.trim(heading),
        tasks = {},
      }
    elseif current_column then
      local item_text = line:match("^%s*[%-*+]%s*(.*)$")
      if item_text and item_text ~= "" then
        local parsed = parse_task_text(item_text)
        parsed.line = i
        parsed.raw = line
        table.insert(current_column.tasks, parsed)
      end
    end
  end

  if current_column then
    table.insert(columns, current_column)
  end

  return { columns = columns }
end

--- Convenience function to parse a markdown file directly
--- @param filepath string Path to the markdown file
--- @return table|nil Parsed board structure, or nil on error
--- @return string|nil Error message if parsing failed
function M.parse_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil, "Cannot open file: " .. filepath
  end

  local content = file:read("*a")
  file:close()

  return M.parse(content)
end

return M
