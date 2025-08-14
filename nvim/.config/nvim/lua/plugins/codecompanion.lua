return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("codecompanion").setup {
        -- default adapters
        strategies = {
          chat = {
            adapter = "anthropic",
          },
          inline = {
            adapter = "anthropic",
          },
          cmd = {
            adapter = "anthropic",
          },
        },
        -- adapter configs
        adapters = {
          anthropic = function()
            return require("codecompanion.adapters").extend("anthropic", {
              schema = {
                model = {
                  default = "claude-sonnet-4-20250514",
                },
              },
            })
          end,
        },
      }

      vim.keymap.set(
        { "n", "v" },
        "<leader>ck",
        "<cmd>CodeCompanionActions<cr>",
        { noremap = true, silent = true }
      )
      vim.keymap.set(
        { "n", "v" },
        "<leader>cc",
        "<cmd>CodeCompanionChat Toggle<cr>",
        { noremap = true, silent = true }
      )
      vim.keymap.set("v", "ga", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true })
      vim.cmd [[cab cc CodeCompanion]]
    end,
  },
}
