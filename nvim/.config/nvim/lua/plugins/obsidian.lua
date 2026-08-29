local is_wsl = vim.fn.has "wsl" == 1
local vault_path = is_wsl and "/mnt/c/Users/joe.qiu/Desktop/notes"
  or vim.fn.expand "~/Documents/notes"
local vault_exists = (vim.uv or vim.loop).fs_stat(vault_path) ~= nil

return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  enabled = vault_exists,

  cmd = "Obsidian",

  keys = {
    { "<leader>on", "<cmd>Obsidian new<CR>", desc = "Create New Note" },
    { "<leader>os", "<cmd>Obsidian search<CR>", desc = "Search Obsidian" },
    { "<leader>oq", "<cmd>Obsidian quick_switch<CR>", desc = "Quick Switch" },
    { "<leader>ot", "<cmd>Obsidian today<CR>", desc = "Daily Note" },
  },

  event = {
    "BufReadPre " .. vault_path .. "/**/*.md",
    "BufNewFile " .. vault_path .. "/**/*.md",
  },

  dependencies = {
    "nvim-lua/plenary.nvim",
    "ibhagwan/fzf-lua",
    "nvim-treesitter/nvim-treesitter",
    "MeanderingProgrammer/render-markdown.nvim",
  },

  config = function()
    require("obsidian").setup {
      legacy_commands = false,

      workspaces = {
        {
          name = "notes",
          path = vault_path,
        },
      },

      picker = {
        name = "fzf-lua",
      },

      daily_notes = {
        folder = "daily",
        date_format = "%Y-%m-%d",
        alias_format = "%B %-d, %Y",
        default_tags = { "daily-notes" },
        template = nil,
        workdays_only = false,
      },

      new_notes_location = "current_dir",

      -- Create Zettelkasten IDs from a title or random uppercase suffix.
      ---@param title string|?
      ---@return string
      note_id_func = function(title)
        local suffix = ""
        if title ~= nil then
          suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
        else
          for _ = 1, 4 do
            suffix = suffix .. string.char(math.random(65, 90))
          end
        end
        return tostring(os.time()) .. "-" .. suffix
      end,

      frontmatter = {
        enabled = true,
        func = function(note)
          -- Overwrite title with the first # header in the buffer, if present.
          local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
          for _, line in ipairs(lines) do
            local header = line:match "^# (.+)$"
            if header then
              note.title = header
              break
            end
          end

          if note.title then
            note:add_alias(note.title)
          end

          if note.metadata then
            note.metadata.title = nil
          end

          local out = { id = note.id, aliases = note.aliases, tags = note.tags, title = note.title }

          -- Keep any manually added frontmatter fields.
          if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
            for k, v in pairs(note.metadata) do
              out[k] = v
            end
          end

          return out
        end,

        sort = { "id", "aliases", "tags", "title" },
      },
    }

    vim.api.nvim_create_autocmd("User", {
      pattern = "ObsidianNoteEnter",
      callback = function(ev)
        vim.keymap.set(
          "n",
          "<leader>oo",
          "<cmd>Obsidian open<CR>",
          { buffer = ev.buf, desc = "Open in Obsidian App" }
        )
        vim.keymap.set(
          "n",
          "<leader>of",
          "<cmd>Obsidian follow_link vsplit<CR>",
          { buffer = ev.buf, desc = "Follow Link with Split" }
        )
        vim.keymap.set(
          "n",
          "<leader>ob",
          "<cmd>Obsidian backlinks<CR>",
          { buffer = ev.buf, desc = "Backlinks" }
        )
      end,
    })
  end,
}
