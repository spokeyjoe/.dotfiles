-- vim.g & vim.opt
require "configs"

-- keymaps
require "keymaps"

-- bootstrap Lazy
require "bootlazy"

-- load plugins
require("lazy").setup {
  spec = { { import = "plugins" } },
  rocks = { enabled = false },
}

-- colorscheme
require "colorscheme"
