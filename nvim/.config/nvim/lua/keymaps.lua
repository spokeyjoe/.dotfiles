-- map jk to <Esc> in insert mode
vim.keymap.set("i", "jk", "<Esc>", { noremap = true, silent = true })

-- ts to tab split
vim.keymap.set("n", "ts", "<cmd>tab split<CR>", { desc = "[T]ab [S]plit" })

-- <Esc> to clear search highlighting
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- diagnostic messages
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show [E]rror messages" })

-- exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- split window navigation
vim.keymap.set("n", "\\", "<C-w><C-w>", { desc = "Move to the next window" })

-- gq to format with Conform
vim.keymap.set("o", "q", function()
  require("conform").format { lsp_fallback = true, async = true }
end, { desc = "Format with Conform" })

-- highlight when yanking
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})
