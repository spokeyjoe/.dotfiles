local is_wsl = vim.fn.has "wsl" == 1
local vault_path = is_wsl and "/mnt/c/Users/joe.qiu/Desktop/notes"
  or vim.fn.expand "~/Documents/notes"

return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = true,

  cmd = { "ObsidianSearch", "ObsidianQuickSwitch", "ObsidianToday", "ObsidianNew" },

  event = {
    "BufReadPre " .. vault_path .. "/**/*.md",
    "BufNewFile " .. vault_path .. "/**/*.md",

    "BufEnter " .. vault_path,
  },

  dependencies = {
    "nvim-lua/plenary.nvim",
    "hrsh7th/nvim-cmp",
    "nvim-telescope/telescope.nvim",
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

      daily_notes = {
        folder = "daily",
        date_format = "%Y-%m-%d",
        alias_format = "%B %-d, %Y",
        default_tags = { "daily-notes" },
        template = nil,
        workdays_only = false,
      },

      completion = {
        -- Enables completion using nvim_cmp
        nvim_cmp = false,
        -- Enables completion using blink.cmp
        blink = true,
        -- Trigger completion at 2 chars.
        min_chars = 2,
        match_case = true,
      },

      new_notes_location = "current_dir",

      -- Optional, customize how wiki links are formatted. You can set this to one of:
      -- _ "use_alias_only", e.g. '[[Foo Bar]]'
      -- _ "prepend*note_id", e.g. '[[foo-bar|Foo Bar]]'
      -- * "prepend*note_path", e.g. '[[foo-bar.md|Foo Bar]]'
      -- * "use_path_only", e.g. '[[foo-bar.md]]'
      wiki_link_func = "prepend_note_id",

      -- Optional, customize how note IDs are generated given an optional title.
      ---@param title string|?
      ---@return string
      note_id_func = function(title)
        -- Create note IDs in a Zettelkasten format with a timestamp and a suffix.
        -- In this case a note with the title 'My new note' will be given an ID that looks
        -- like '1657296016-my-new-note', and therefore the file name '1657296016-my-new-note.md'
        local suffix = ""
        if title ~= nil then
          -- If title is given, transform it into valid file name.
          suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
        else
          -- If title is nil, just add 4 random uppercase letters to the suffix.
          for _ = 1, 4 do
            suffix = suffix .. string.char(math.random(65, 90))
          end
        end
        return tostring(os.time()) .. "-" .. suffix
      end,

      ---@class obsidian.config.FrontmatterOpts
      ---
      --- Whether to enable frontmatter, boolean for global on/off, or a function that takes filename and returns boolean.
      ---@field enabled? (fun(fname: string?): boolean)|boolean
      ---
      --- Function to turn Note attributes into frontmatter.
      ---@field func? fun(note: obsidian.Note): table<string, any>
      --- Function that is passed to table.sort to sort the properties, or a fixed order of properties.
      ---
      --- List of string that sorts frontmatter properties, or a function that compares two values, set to vim.NIL/false to do no sorting
      ---@field sort? string[] | (fun(a: any, b: any): boolean) | vim.NIL | boolean
      frontmatter = {
        enabled = true,
        func = function(note)
          -- Overwrite title with the first # header in the buffer, if present
          local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
          for _, line in ipairs(lines) do
            local header = line:match("^# (.+)$")
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

          -- `note.metadata` contains any manually added fields in the frontmatter.
          -- So here we just make sure those fields are kept in the frontmatter.
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

    vim.keymap.set("n", "<leader>on", "<cmd>Obsidian new<CR>", { desc = "Create New Note" })
    vim.keymap.set("n", "<leader>os", "<cmd>Obsidian search<CR>", { desc = "Search Obsidian" })
    vim.keymap.set("n", "<leader>oq", "<cmd>Obsidian quick_switch<CR>", { desc = "Quick Switch" })
    vim.keymap.set("n", "<leader>ot", "<cmd>Obsidian today<CR>", { desc = "Daily Note" })

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
