return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("neo-tree").setup {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
      close_if_last_window = true,
    }
    vim.keymap.set(
      "n",
      "<leader>t",
      "<cmd>Neotree toggle reveal_force_cwd<CR>",
      { desc = "Toggle Neotree" }
    )
  end,
}
