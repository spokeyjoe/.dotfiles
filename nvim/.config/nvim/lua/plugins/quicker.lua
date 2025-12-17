return {
  "stevearc/quicker.nvim",
  ft = "qf",
  ---@module "quicker"
  ---@type quicker.SetupOptions
  opts = {},

  config = function()
    require("quicker").setup {
      vim.keymap.set("n", "<leader>q", function()
        require("quicker").toggle()
      end, {
        desc = "Toggle quickfix",
      }),
    }
  end,
}
