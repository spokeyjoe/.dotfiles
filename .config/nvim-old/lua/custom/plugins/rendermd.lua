return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
  opts = {
    file_types = { 'markdown', 'Avante' },
  },
  ft = { 'markdown', 'Avante' },

  config = function()
    require('render-markdown').setup {
      heading = {
        sign = false,
      },

      bullet = {
        right_pad = 1,
      },
    }
  end,
}
