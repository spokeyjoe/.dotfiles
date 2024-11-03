vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.have_nerd_font = true

vim.opt.tabstop = 4

vim.opt.number = true

vim.opt.cursorline = true

-- highlight search results
vim.opt.hlsearch = true

-- show 12 lines while scrolling
vim.opt.scrolloff = 12

-- we already have mode shown in the status line
vim.opt.showmode = false

-- sync clipboard between OS and Neovim
vim.opt.clipboard = "unnamedplus"

-- case-insensitive search, unless capital letters are used
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- decrease mapped sequence wait time
vim.opt.timeoutlen = 300

-- display whitespace characters
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
