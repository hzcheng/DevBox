-- Alpha - Startup dashboard
return {
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      -- Set header
      dashboard.section.header.val = {
        "                                                     ",
        "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
        "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
        "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
        "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
        "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
        "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
        "                                                     ",
        "        [ DevBox Development Environment ]            ",
      }

      -- Set menu
      dashboard.section.buttons.val = {
        dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
        dashboard.button("<C-p>", "  Find file", ":Telescope find_files<CR>"),
        dashboard.button("<S-p>", "  Recent files", ":Telescope oldfiles<CR>"),
        dashboard.button("<C-b>", "  File explorer", ":NvimTreeToggle<CR>"),
        dashboard.button("s", "  Settings", ":e ~/.config/nvim/init.lua <CR>"),
        dashboard.button("q", "  Quit NVIM", ":qa<CR>"),
      }

      -- Set footer
      local function footer()
        return "Neovim " .. vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch
      end

      dashboard.section.footer.val = footer()

      dashboard.opts.opts.noautocmd = true

      alpha.setup(dashboard.opts)
    end,
  },
}
