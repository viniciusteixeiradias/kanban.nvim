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

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "kanban.nvim" })
end

return M
