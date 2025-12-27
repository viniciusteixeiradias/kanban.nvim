local M = {}

function M.get_project_root()
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error == 0 and git_root then
    return git_root
  end
  return vim.fn.getcwd()
end

function M.path_exists(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil
end

function M.expand_path(path)
  return vim.fn.expand(path)
end

function M.ensure_parent_dir(path)
  local parent = vim.fn.fnamemodify(path, ":h")
  if not M.path_exists(parent) then
    vim.fn.mkdir(parent, "p")
  end
end

function M.read_file(path)
  local file = io.open(path, "r")

  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  if content == "" then
    return nil
  end

  return content
end

function M.write_file(path, content)
  local file = io.open(path, "w")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "kanban.nvim" })
end

return M
