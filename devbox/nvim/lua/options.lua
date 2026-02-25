-- Basic Neovim Options

-- Encoding
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"

-- Numbers
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Tabs and indentation
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true

-- Line wrapping
vim.opt.wrap = false

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Appearance
vim.opt.termguicolors = true
vim.opt.background = "dark"
vim.opt.signcolumn = "yes"
vim.opt.colorcolumn = "80"

-- Backspace
vim.opt.backspace = "indent,eol,start"

-- Clipboard
vim.opt.clipboard:append("unnamedplus")

-- Split windows
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Scrolling
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

-- Enable mouse
vim.opt.mouse = "a"

-- Disable swap and backup
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

-- Update time
vim.opt.updatetime = 50

-- Timeout for mapped sequences
vim.opt.timeoutlen = 300

-- Show matching brackets
vim.opt.showmatch = true

-- Command height
vim.opt.cmdheight = 1

-- Completeopt for better completion experience
vim.opt.completeopt = { "menuone", "noselect", "noinsert" }

-- Don't show mode (lualine will handle it)
vim.opt.showmode = false

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable netrw (using nvim-tree instead)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
