return {
  "saghen/blink.cmp",
  event = "VimEnter",
  version = "1.*",
  dependencies = {
    -- Snippet Engine
    {
      "L3MON4D3/LuaSnip",
      version = "2.*",
      build = (function()
        if vim.fn.has "win32" == 1 or vim.fn.executable "make" == 0 then
          return
        end
        return "make install_jsregexp"
      end)(),
      dependencies = {},
      opts = {},
    },
    "folke/lazydev.nvim",
  },
  --- @module 'blink.cmp'
  --- @type blink.cmp.Config
  opts = {
    keymap = {
      preset = "default",
      ["<Tab>"] = { "select_next", "fallback" },
      ["<S-Tab>"] = { "select_prev", "fallback" },
    },

    appearance = {
      nerd_font_variant = "mono",
    },

    completion = {
      documentation = { auto_show = false, auto_show_delay_ms = 500 },
      list = {
        selection = {
          preselect = false,
        },
      },
    },

    sources = {
      default = { "lsp", "path", "snippets", "buffer", "lazydev" },
      providers = {
        lazydev = { module = "lazydev.integrations.blink", score_offset = 100 },
      },
    },

    snippets = { preset = "luasnip" },
    fuzzy = { implementation = "lua" },
    signature = { enabled = true },
  },
}
