return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  event = "BufEnter",
  config = function()
    require("neo-tree").setup {
      close_if_last_window = true,
      use_libuv_file_watcher = true,
      filesystem = {
        commands = {
          copy_selector = function(state)
            local node = state.tree:get_node()
            local filepath = node:get_id()
            local filename = node.name
            local modify = vim.fn.fnamemodify

            local vals = {
              ["1"] = filepath,
              ["2"] = modify(filepath, ":."),
              ["3"] = filename,
            }

            local options = {
              "1. Absolute Path: " .. vals["1"],
              "2. Relative Path: " .. vals["2"],
              "3. Filename:      " .. vals["3"],
            }

            vim.ui.select(options, { prompt = "Copy to Clipboard" }, function(choice)
              if choice then
                local i = choice:sub(1, 1)
                vim.fn.setreg("+", vals[i])
                vim.notify("Copied: " .. vals[i])
              end
            end)
          end,
        },
        window = {
          mappings = {
            ["Y"] = "copy_selector",
          },
        },
      },
    }
    vim.keymap.set(
      "n",
      "<leader>t",
      "<cmd>Neotree toggle reveal_force_cwd<CR>",
      { desc = "Toggle Neotree" }
    )
  end,
}
