return {
  "stevearc/quicker.nvim",
  ft = "qf",
  keys = {
    {
      "<leader>q",
      function()
        require("quicker").toggle()
      end,
      desc = "Toggle quickfix",
    },
  },
  ---@module "quicker"
  ---@type quicker.SetupOptions
  opts = {},
}
