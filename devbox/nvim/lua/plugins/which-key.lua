-- Which-key - Keybinding helper
return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
    config = function()
      local wk = require("which-key")
      wk.setup({
        plugins = {
          marks = true,
          registers = true,
          spelling = {
            enabled = true,
            suggestions = 20,
          },
          presets = {
            operators = true,
            motions = true,
            text_objects = true,
            windows = true,
            nav = true,
            z = true,
            g = true,
          },
        },
        icons = {
          breadcrumb = "»",
          separator = "➜",
          group = "+",
        },
        win = {
          border = "none",
          position = "bottom",
          margin = { 1, 0, 1, 0 },
          padding = { 1, 2, 1, 2 },
          winblend = 0,
          zindex = 1000,
        },
        layout = {
          height = { min = 4, max = 25 },
          width = { min = 20, max = 50 },
          spacing = 3,
          align = "left",
        },
        -- filter 选项已在新版中移除或需要函数值
        show_help = true,
        show_keys = true,
        triggers = { "auto" },
        delay = vim.opt.timeoutlen:get(),
        replace = {
          -- ["<space>"] = "SPC",
          -- ["<cr>"] = "RET",
          -- ["<tab>"] = "TAB",
        },
        defer = { operators = true },
        keys = {
          scroll_down = "<c-d>",
          scroll_up = "<c-u>",
        },
        disable = {
          buftypes = {},
          ft = { "TelescopePrompt" },
        },
      })

      -- Register mappings using the new spec format
      wk.add({
        { "`", "'", desc = "which_key_ignore" },
        { "'", "'", desc = "which_key_ignore" },
        { "g`", "g'", desc = "which_key_ignore" },
        { "g'", "g'", desc = "which_key_ignore" },
        { '"', '"', desc = "which_key_ignore" },
        { "<c-r>", "<c-r>", desc = "which_key_ignore" },
        { "z=", "z=", desc = "which_key_ignore" },
        -- Register groups for better which-key display
        { "<leader>g", group = "Git" },
        { "<leader>h", group = "Hunk (Git)" },
      })
    end,
  },
}
