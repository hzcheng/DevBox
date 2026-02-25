-- Keymaps

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Clear highlights on search
keymap("n", "<Esc>", "<cmd>nohlsearch<CR>", opts)

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Resize with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Navigate buffers
keymap("n", "<S-l>", ":bnext<CR>", opts)
keymap("n", "<S-h>", ":bprevious<CR>", opts)
keymap("n", "<leader>bd", ":bdelete<CR>", { desc = "Close buffer" })

-- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Move text up and down
keymap("v", "<A-j>", ":m .+1<CR>==", opts)
keymap("v", "<A-k>", ":m .-2<CR>==", opts)
keymap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
keymap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

-- Better paste (don't replace clipboard when pasting over selection)
keymap("v", "p", '"_dP', opts)

-- VSCode-like keymaps
-- Save
keymap("n", "<C-s>", ":w<CR>", opts)
keymap("i", "<C-s>", "<Esc>:w<CR>a", opts)

-- Find and replace
keymap("n", "<C-f>", "/", opts)
keymap("n", "<C-h>", ":%s///g<Left><Left><Left>", { desc = "Find and replace" })

-- Duplicate line (VSCode: Shift+Alt+Down)
keymap("n", "<S-A-Down>", "yyp", opts)
keymap("i", "<S-A-Down>", "<Esc>yyp", opts)

-- Delete line
keymap("n", "<C-d>", "dd", opts)

-- Comment (handled by Comment.nvim)
keymap("n", "<C-]>", "gcc", { remap = true, desc = "Toggle comment" })
keymap("v", "<C-]>", "gc", { remap = true, desc = "Toggle comment" })

-- Telescope (VSCode-like fuzzy finder)
keymap("n", "<C-p>", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
keymap("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
keymap("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Help tags" })
keymap("n", "<leader>fr", "<cmd>Telescope oldfiles<CR>", { desc = "Recent files" })

-- Nvim-tree (VSCode-like file explorer)
keymap("n", "<C-b>", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
keymap("n", "<leader>e", "<cmd>NvimTreeFocus<CR>", { desc = "Focus file explorer" })

-- LSP
keymap("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
keymap("n", "gr", vim.lsp.buf.references, { desc = "Go to references" })
keymap("n", "gI", vim.lsp.buf.implementation, { desc = "Go to implementation" })
keymap("n", "<leader>D", vim.lsp.buf.type_definition, { desc = "Type definition" })
keymap("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
keymap("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
keymap("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
keymap("n", "<leader>ds", vim.lsp.buf.document_symbol, { desc = "Document symbols" })
keymap("n", "<leader>ws", vim.lsp.buf.workspace_symbol, { desc = "Workspace symbols" })

-- Diagnostics
keymap("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show diagnostic" })
keymap("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
keymap("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
keymap("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostic list" })

-- Format
keymap("n", "<leader>f", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "Format document" })

-- Terminal
keymap("n", "<C-`>", "<cmd>ToggleTerm<CR>", { desc = "Toggle terminal" })
keymap("t", "<C-`>", "<cmd>ToggleTerm<CR>", { desc = "Toggle terminal" })
keymap("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

-- Which-key
keymap("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer local keymaps" })
