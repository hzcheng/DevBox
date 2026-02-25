-- Colorscheme - VSCode-like theme
return {
  {
    "Mofiqul/vscode.nvim",
    priority = 1000,
    config = function()
      require("vscode").setup({
        -- Enable transparent background
        transparent = false,
        -- Enable italic comment
        italic_comments = true,
        -- Disable nvim-tree background color
        disable_nvimtree_bg = true,
        -- Override colors
        color_overrides = {
          vscLineNumber = "#858585",
        },
      })
      vim.cmd.colorscheme("vscode")
    end,
  },
}
