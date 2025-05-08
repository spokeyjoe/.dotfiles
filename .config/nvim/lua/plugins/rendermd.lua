return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.nvim" }, -- if you use the mini.nvim suite
  opts = {
    file_types = { "markdown" },
  },
  ft = { "markdown" },

  config = function()
    require("render-markdown").setup {
      heading = {
        sign = false,
      },

      bullet = {
        right_pad = 1,
      },

      latex = {
        enabled = true,
        converter = "latex2text",
        highlight = "RenderMarkdownMath",
        top_pad = 0,
        bottom_pad = 0,
      },
    }
  end,
}
