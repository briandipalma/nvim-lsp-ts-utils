local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")
local s = require("nvim-lsp-ts-utils.state")

local lsp = vim.lsp

local rename_file = function(source, target)
    lsp.buf.execute_command({
        command = "_typescript.applyRenameFile",
        arguments = {
            {
                sourceUri = vim.uri_from_fname(source),
                targetUri = vim.uri_from_fname(target)
            }
        }
    })
end

local M = {}

M.manual = function(target)
    local ft_ok, ft_err = pcall(u.file.check_ft)
    if not ft_ok then error(ft_err) end

    local bufnr = vim.api.nvim_get_current_buf()
    local source = u.buffer.name(bufnr)

    local status
    if not target then
        status, target = pcall(vim.fn.input, "New path: ", source, "file")
        if not status or target == "" or target == source then return end
    end

    local exists = u.file.exists(target)
    if exists then
        local confirm = vim.fn.confirm("File exists! Overwrite?", "&Yes\n&No")
        if confirm ~= 1 then return end
    end

    rename_file(source, target)

    local modified = vim.fn.getbufvar(bufnr, "&modified")
    if modified then vim.cmd("silent noautocmd w") end

    -- prevent watcher callback from triggering
    s.ignore()
    u.file.mv(source, target)

    vim.cmd("e " .. target)
    vim.cmd(bufnr .. "bwipeout!")
end

M.on_move = function(source, target)
    if source == target then return end

    if o.get().require_confirmation_on_move then
        local confirm = vim.fn.confirm("Update imports for file " .. target ..
                                           "?", "&Yes\n&No")
        if confirm ~= 1 then return end
    end

    local source_bufnr = u.buffer.bufnr(source)
    local target_bufnr = u.buffer.bufnr(target)
    if target_bufnr then vim.cmd(target_bufnr .. "bwipeout!") end

    -- coc.nvim seems to use bufadd and bufload, but these won't work if the user is in a terminal buffer
    -- vim.fn.bufadd(target)
    -- vim.fn.bufload(target)

    -- edit will override whatever is in the terminal buffer, which is annoying
    -- but it'll update imports correctly
    vim.cmd("edit " .. target)
    rename_file(source, target)

    -- wait to do this to ensure at least one buffer is open
    if source_bufnr then vim.cmd(source_bufnr .. "bwipeout!") end
end

return M
