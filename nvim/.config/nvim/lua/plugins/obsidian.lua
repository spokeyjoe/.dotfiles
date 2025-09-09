return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = true,
  event = {
    "BufReadPre /Users/josephqiu/Documents/notes/*.md",
    "BufNewFile /Users/josephqiu/Documents/notes/*.md",
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
          path = "~/Documents/notes",
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

      -- Optional, alternatively you can customize the frontmatter data.
      ---@return table
      note_frontmatter_func = function(note)
        if note.title then
          note:add_alias(note.title)
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
    }

    vim.api.nvim_create_autocmd("User", {
      pattern = "ObsidianNoteEnter",
      callback = function(ev)
        vim.keymap.set(
          "n",
          "<leader>on",
          "<cmd>Obsidian new<CR>",
          { buffer = ev.buf, desc = "Create New Note" }
        )
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "ObsidianNoteEnter",
      callback = function(ev)
        vim.keymap.set(
          "n",
          "<leader>oo",
          "<cmd>Obsidian open<CR>",
          { buffer = ev.buf, desc = "Open in Obsidian" }
        )
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "ObsidianNoteEnter",
      callback = function(ev)
        vim.keymap.set(
          "n",
          "<leader>os",
          "<cmd>Obsidian search<CR>",
          { buffer = ev.buf, desc = "Search Obsidian" }
        )
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "ObsidianNoteEnter",
      callback = function(ev)
        vim.keymap.set(
          "n",
          "<leader>oq",
          "<cmd>Obsidian quick_switch<CR>",
          { buffer = ev.buf, desc = "Quick Switch" }
        )
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "ObsidianNoteEnter",
      callback = function(ev)
        vim.keymap.set(
          "n",
          "<leader>ot",
          "<cmd>Obsidian today<CR>",
          { buffer = ev.buf, desc = "Daily Note" }
        )
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "ObsidianNoteEnter",
      callback = function(ev)
        vim.keymap.set(
          "n",
          "<leader>of",
          "<cmd>Obsidian follow_link vsplit<CR>",
          { buffer = ev.buf, desc = "Follow Link with Split" }
        )
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "ObsidianNoteEnter",
      callback = function(ev)
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
