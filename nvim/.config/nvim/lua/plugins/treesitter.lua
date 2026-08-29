return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main", -- the rewrite; legacy `master` is frozen
    lazy = false, -- this plugin does not support lazy-loading
    build = ":TSUpdate",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
    },
    config = function()
      local ok, ts = pcall(require, "nvim-treesitter")
      -- Guard against mid-migration state (plugin still on legacy master).
      if not ok or type(ts.setup) ~= "function" or type(ts.install) ~= "function" then
        vim.notify(
          "nvim-treesitter: run :Lazy restore to switch to the main branch",
          vim.log.levels.WARN
        )
        return
      end
      ts.setup()

      -- Parsers to always have (replaces ensure_installed).
      local ensure_installed = {
        "bash",
        "c",
        "cpp",
        "cuda",
        "diff",
        "html",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "vim",
        "vimdoc",
        "yaml",
      }
      local install_job = ts.install(ensure_installed) -- async, no-op if installed
      if #vim.api.nvim_list_uis() == 0 and install_job then
        -- Headless (bootstrap/CI): wait for parsers to finish building.
        pcall(function()
          install_job:wait(300000)
        end)
      end

      -- Textobjects: select (replaces the old textobjects.select module).
      require("nvim-treesitter-textobjects").setup {
        select = { lookahead = true },
      }
      local ts_select = require "nvim-treesitter-textobjects.select"
      for lhs, capture in pairs {
        af = "@function.outer",
        ["if"] = "@function.inner",
        ac = "@class.outer",
        ic = "@class.inner",
        al = "@loop.outer",
        il = "@loop.inner",
      } do
        vim.keymap.set({ "x", "o" }, lhs, function()
          ts_select.select_textobject(capture, "textobjects")
        end, { desc = "treesitter " .. capture })
      end

      -- Highlighting / auto-install / indentation (replaces the old
      -- highlight/auto_install/indent modules — features now live in
      -- Neovim itself and are enabled per filetype).
      local installing = {}
      vim.api.nvim_create_autocmd("FileType", {
        desc = "nvim-treesitter: start highlighting, auto-install parser",
        callback = function(args)
          local buf, ft = args.buf, args.match
          local lang = vim.treesitter.language.get_lang(ft)

          if pcall(vim.treesitter.start, buf) then
            -- Treesitter highlight active: keep regex syntax only as a
            -- supplement for cpp (was additional_vim_regex_highlighting).
            vim.bo[buf].syntax = (ft == "cpp") and ft or ""
            -- Treesitter indentation (experimental; was disabled for cpp).
            if ft ~= "cpp" then
              vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          elseif
            lang
            and not installing[lang]
            and vim.list_contains(ts.get_available(), lang)
            and not vim.list_contains(ts.get_installed(), lang)
          then
            -- was auto_install = true: fetch missing parsers in the
            -- background; highlighting kicks in for the next buffer of
            -- this filetype. Flag prevents re-triggering this session.
            installing[lang] = true
            ts.install { lang }
          end
        end,
      })
    end,
  },
}
