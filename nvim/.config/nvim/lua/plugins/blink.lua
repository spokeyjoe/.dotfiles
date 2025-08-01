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
      ["<C-space>"] = { "show", "hide", "show_documentation", "hide_documentation" },
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
      default = { "minuet", "lsp", "path", "snippets", "buffer", "lazydev" },
      providers = {
        lazydev = { module = "lazydev.integrations.blink", score_offset = 100 },
        minuet = {
          name = "minuet",
          module = "minuet.blink",
          async = true,
          -- Should match minuet.config.request_timeout * 1000,
          -- since minuet.config.request_timeout is in seconds
          timeout_ms = 3000,
          score_offset = 500, -- Gives minuet higher priority among suggestions
        },
      },
    },

    snippets = { preset = "luasnip" },
    fuzzy = { implementation = "lua" },
    signature = { enabled = true },
  },
}
