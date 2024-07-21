return {
  {
    'jim-fx/sudoku.nvim',
    cmd = 'Sudoku',
    config = function()
      require('sudoku').setup {
        -- configuration ...
      }
    end,
  },
  {
    'alanfortlink/blackjack.nvim',
    requires = { 'nvim-lua/plenary.nvim' },
  },
  {
    name = 'gomoku.nvim',
    dir = '~/Documents/Code/gomoku.nvim',
    requires = { 'nvim-lua/plenary.nvim' },
  },
}
