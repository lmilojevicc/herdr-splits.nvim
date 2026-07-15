local source = debug.getinfo(1, 'S').source
assert(source:sub(1, 1) == '@', 'could not locate minimal_init.lua')

local root = vim.fn.fnamemodify(source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. '/deps/mini.test')

require('mini.test').setup({
  collect = {
    find_files = function()
      return vim.fn.glob(root .. '/tests/test_*.lua', true, true)
    end,
  },
})
