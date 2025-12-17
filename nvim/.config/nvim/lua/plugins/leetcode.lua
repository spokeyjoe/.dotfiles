return {
  "kawre/leetcode.nvim",
  dependencies = {
    -- include a picker of your choice, see picker section for more details
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("leetcode").setup {
      ---@type lc.lang
      lang = "cpp",

      vim.keymap.set("n", "<leader>lc", "<cmd>Leet<cr>", {
        desc = "[L]eetCode",
      }),
      vim.keymap.set("n", "<leader>lt", "<cmd>Leet test<cr>", {
        desc = "[L]eetCode Run [T]est",
      }),
      vim.keymap.set("n", "<leader>li", "<cmd>Leet info<cr>", {
        desc = "[L]eetCode Question [I]nfo",
      }),
      vim.keymap.set("n", "<leader>ls", "<cmd>Leet submit<cr>", {
        desc = "[L]eetCode [S]ubmit",
      }),
      vim.keymap.set("n", "<leader>ll", "<cmd>Leet last_submit<cr>", {
        desc = "[L]eetCode [L]ast Submit",
      }),
      vim.keymap.set("n", "<leader>ly", "<cmd>Leet yank<cr>", {
        desc = "[L]eetCode [Y]ank Solution",
      }),
    }
  end,
}
