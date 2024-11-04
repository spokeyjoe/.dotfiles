return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup {
        close_if_last_window = true,
        popup_border_style = "rounded",
        filesystem = {
          hijack_netrw_behavior = "open_default",
        },
      }

      vim.cmd [[nnoremap <leader>tf :Neotree toggle reveal_force_cwd<cr>]]
    end,
  },
}
