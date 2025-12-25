return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local fzf = require "fzf-lua"
    local actions = require "fzf-lua.actions"

    fzf.setup {
      "default-title",

      ui_select = function(fzf_opts, items)
        return vim.tbl_deep_extend("force", fzf_opts, {
          prompt = "Code Actions> ",
          winopts = {
            height = 0.33,
            width = 0.33,
          },
        })
      end,

      actions = {
        files = {
          ["default"] = actions.file_edit,
          ["ctrl-s"] = actions.file_vsplit,
          ["ctrl-t"] = actions.file_tabedit,
        },
        grep = {
          ["default"] = actions.file_edit,
          ["ctrl-s"] = actions.file_vsplit,
          ["ctrl-t"] = actions.file_tabedit,
        },
      },

      winopts = {
        preview = {
          -- default = "bat",
          layout = "flex",
        },
      },
    }

    fzf.register_ui_select()

    vim.keymap.set("n", "<leader>sh", fzf.help_tags, { desc = "[S]earch [H]elp" })
    vim.keymap.set("n", "<leader>sk", fzf.keymaps, { desc = "[S]earch [K]eymaps" })
    vim.keymap.set("n", "<leader>sf", fzf.files, { desc = "[S]earch [F]iles" })
    vim.keymap.set("n", "<leader>sg", fzf.live_grep, { desc = "[S]earch by [G]rep" })
    vim.keymap.set("n", "<leader>sr", fzf.resume, { desc = "[S]earch [R]esume" })
    vim.keymap.set("n", "<leader><leader>", fzf.buffers, { desc = "[ ] Find existing buffers" })

    -- Search within the current file's directory
    vim.keymap.set("n", "<leader>s/", function()
      local current_file = vim.api.nvim_buf_get_name(0)
      local search_dir = nil
      if current_file ~= "" then
        search_dir = vim.fs.dirname(current_file)
      end

      fzf.live_grep {
        cwd = search_dir,
        prompt = "Live Grep ("
          .. (search_dir and vim.fn.fnamemodify(search_dir, ":t") or "cwd")
          .. ")> ",
      }
    end, { desc = "[S]earch [/] in Directory" })

    -- Search Neovim configuration files
    vim.keymap.set("n", "<leader>sn", function()
      fzf.files { cwd = vim.fn.stdpath "config" }
    end, { desc = "[S]earch [N]eovim files" })
  end,
}
