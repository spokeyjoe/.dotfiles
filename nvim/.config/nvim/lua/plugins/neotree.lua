return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  event = "BufEnter",
  config = function()
    require("neo-tree").setup {
      close_if_last_window = true,
      use_libuv_file_watcher = true,
    }
    vim.keymap.set(
      "n",
      "<leader>t",
      "<cmd>Neotree toggle reveal_force_cwd<CR>",
      { desc = "Toggle Neotree" }
    )
  end,
}
