return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>f",
        function()
          local clang_format_only = { c = true, cpp = true }
          local lsp_format = clang_format_only[vim.bo.filetype] and "never" or "fallback"
          require("conform").format { async = true, lsp_format = lsp_format }
        end,
        mode = "",
        desc = "[F]ormat buffer",
      },
    },
    init = function()
      -- Make the built-in gq formatting operator use Conform.
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- format_on_save itself still runs for C/C++; only disable falling
        -- back to clangd so clang-format is the single source of truth.
        local disable_filetypes = { c = true, cpp = true }
        local lsp_format_opt
        if disable_filetypes[vim.bo[bufnr].filetype] then
          lsp_format_opt = "never"
        else
          lsp_format_opt = "fallback"
        end
        return {
          timeout_ms = 500,
          lsp_format = lsp_format_opt,
        }
      end,
      formatters_by_ft = {
        lua = { "stylua" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        python = { "ruff_format" },
      },
    },
  },
}
