vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.have_nerd_font = true

vim.opt.number = true

vim.opt.cursorline = true

vim.opt.conceallevel = 2

-- relative line numbers
vim.opt.relativenumber = true

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

-- how splits are open
vim.opt.splitright = true
vim.opt.splitbelow = true
