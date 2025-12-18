return {
  "neovim/nvim-lspconfig",
  dependencies = {
    { "williamboman/mason.nvim", opts = {} },
    "williamboman/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    -- UI
    { "j-hui/fidget.nvim", opts = {} },
    -- Autocomplee engine
    "saghen/blink.cmp",
  },
  config = function()
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          mode = mode or "n"
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
        end

        local function safe_del_global(keys)
          pcall(vim.keymap.del, "n", keys)
        end

        safe_del_global "grn" -- Rename
        safe_del_global "gra" -- Code Action
        safe_del_global "grr" -- References
        safe_del_global "gri" -- Implementation
        safe_del_global "grt" -- Type Definition

        local fzf = require "fzf-lua"

        map("gd", fzf.lsp_definitions, "[G]oto [D]efinition") --  To jump back, press <C-t>.
        map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
        map("gr", fzf.lsp_references, "[G]oto [R]eferences")
        map("gI", fzf.lsp_implementations, "[G]oto [I]mplementation")
        map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
        map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })
        map("<leader>T", fzf.lsp_typedefs, "[T]ype Definition")
        map("<leader>ds", fzf.lsp_document_symbols, "[D]ocument [S]ymbols")
        map("<leader>ws", fzf.lsp_live_workspace_symbols, "[W]orkspace [S]ymbols")

        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
          map("<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, "[T]oggle Inlay [H]ints")
        end
      end,
    })

    local servers = {
      clangd = {
        capabilities = {
          offsetEncoding = {
            "utf-16",
          },
        },
      },

      ruff = {},

      pyright = {},

      lua_ls = {
        settings = {
          Lua = {
            completion = {
              callSnippet = "Replace",
              diagnostics = { globals = { "vim" } },
            },
          },
        },
      },
    }

    require("mason").setup()

    local ensure_installed = vim.tbl_keys(servers or {})
    vim.list_extend(ensure_installed, { "stylua", "black" })
    require("mason-tool-installer").setup { ensure_installed = ensure_installed }

    require("mason-lspconfig").setup {
      handlers = {
        function(server_name)
          local server_config = servers[server_name] or {}
          server_config.capabilities =
            require("blink.cmp").get_lsp_capabilities(server_config.capabilities)
          vim.lsp.config[server_name] = server_config
          vim.lsp.enable(server_name)
        end,
      },
    }
  end,
}
