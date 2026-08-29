return {
  "kawre/leetcode.nvim",
  dependencies = {
    -- include a picker of your choice, see picker section for more details
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  cmd = "Leet",
  keys = {
    { "<leader>lc", "<cmd>Leet<cr>", desc = "[L]eetCode" },
    { "<leader>lt", "<cmd>Leet test<cr>", desc = "[L]eetCode Run [T]est" },
    { "<leader>li", "<cmd>Leet info<cr>", desc = "[L]eetCode Question [I]nfo" },
    { "<leader>ls", "<cmd>Leet submit<cr>", desc = "[L]eetCode [S]ubmit" },
    { "<leader>ll", "<cmd>Leet last_submit<cr>", desc = "[L]eetCode [L]ast Submit" },
    { "<leader>ly", "<cmd>Leet yank<cr>", desc = "[L]eetCode [Y]ank Solution" },
  },
  opts = {
    ---@type lc.lang
    lang = "cpp",
  },
}
