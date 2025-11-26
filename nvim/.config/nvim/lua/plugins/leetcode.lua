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
        desc = "LeetCode: Menu",
      }),
      vim.keymap.set("n", "<leader>lt", "<cmd>Leet test<cr>", {
        desc = "LeetCode: Run Test",
      }),
      vim.keymap.set("n", "<leader>li", "<cmd>Leet info<cr>", {
        desc = "LeetCode: Question Info",
      }),
      vim.keymap.set("n", "<leader>ls", "<cmd>Leet submit<cr>", {
        desc = "LeetCode: Submit Solution",
      }),
      vim.keymap.set("n", "<leader>ll", "<cmd>Leet last_submit<cr>", {
        desc = "LeetCode: Last Submit",
      }),
      vim.keymap.set("n", "<leader>ly", "<cmd>Leet yank<cr>", {
        desc = "LeetCode: Copy Solution",
      }),
    }
  end,
}
