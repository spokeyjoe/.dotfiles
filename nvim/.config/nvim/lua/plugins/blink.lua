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
    -- lazydev
    "folke/lazydev.nvim",
    -- copilot
    "fang2hou/blink-copilot",
  },
  --- @module 'blink.cmp'
  --- @type blink.cmp.Config
  opts = {
    keymap = {
      preset = "default",
      ["<Tab>"] = { "select_next", "fallback" },
      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<C-space>"] = { "show", "hide", "show_documentation", "hide_documentation" },
      ["<CR>"] = { "accept", "fallback" },
    },

    appearance = {
      nerd_font_variant = "mono",
    },

    completion = {
      menu = {
        border = "rounded",
        draw = {
          columns = {
            { "kind_icon", "label", gap = 1 },
            { "kind" },
          },
        },
      },

      documentation = {
        auto_show = true,
        auto_show_delay_ms = 100,
        treesitter_highlighting = true,
        window = { border = "rounded" },
      },

      list = {
        selection = {
          preselect = false,
        },
      },
    },

    sources = {
      default = { "copilot", "lsp", "path", "snippets", "buffer", "lazydev" },
      providers = {
        snippets = {
          score_offset = 4,
        },
        lsp = {
          score_offset = 3,
        },
        path = {
          score_offset = 2,
        },
        buffer = {
          score_offset = 1,
        },

        copilot = {
          name = "copilot",
          module = "blink-copilot",
          async = true,
          score_offset = 2,
        },

        lazydev = {
          module = "lazydev.integrations.blink",
        },
      },
    },

    snippets = { preset = "luasnip" },
    fuzzy = { implementation = "lua" },
    signature = { enabled = true },
  },
}
