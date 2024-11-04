-- map jk to <Esc> in insert mode
vim.keymap.set("i", "jk", "<Esc>", { noremap = true, silent = true })

-- <Esc> to clear search highlighting
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- diagnostic messages
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show [E]rror messages" })

-- exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- split window navigation
vim.keymap.set("n", "\\", "<C-w><C-w>", { desc = "Move to the next window" })

-- highlight when yanking
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- obsidian.nvim
vim.keymap.set("n", "<leader>on", "<cmd>ObsidianNew<CR>", { desc = "Create New Note" })
vim.keymap.set("n", "<leader>os", "<cmd>ObsidianSearch<CR>", { desc = "Search Obsidian" })
vim.keymap.set("n", "<leader>oq", "<cmd>ObsidianQuickSwitch<CR>", { desc = "Quick Switch" })

-- neotree
vim.keymap.set(
  "n",
  "<leader>t",
  "<cmd>Neotree toggle reveal_force_cwd<CR>",
  { desc = "Toggle Neotree" }
)
