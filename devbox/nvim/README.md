# DevBox Neovim 使用指南

本文档介绍如何在 DevBox 中使用和自定义 Neovim 配置。

## 目录

- [快速开始](#快速开始)
- [基本操作](#基本操作)
- [快捷键参考](#快捷键参考)
- [插件列表](#插件列表)
- [LSP 配置](#lsp-配置)
- [自定义配置](#自定义配置)
- [故障排除](#故障排除)

## 快速开始

### 1. 启动 Neovim

```bash
nvim                    # 启动 Neovim
nvim <文件名>            # 打开指定文件
nvim .                  # 打开当前目录
```

### 2. 首次启动

首次启动时会自动下载并安装插件管理器 `lazy.nvim` 和所有插件。请等待安装完成。

### 3. 基本操作模式

Neovim 有三种基本模式：

- **Normal 模式** - 默认模式，用于导航和命令
- **Insert 模式** - 编辑模式，按 `i` 进入
- **Visual 模式** - 选择模式，按 `v` 进入

按 `Esc` 键从任何模式返回 Normal 模式。

## 基本操作

### 文件操作

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| 打开文件 | `<Ctrl+P>` | 使用 Telescope 搜索文件 |
| 保存文件 | `<Ctrl+S>` | 保存当前文件 |
| 退出 | `:q` | 退出 Neovim |
| 保存并退出 | `:wq` | 保存并退出 |
| 强制退出 | `:q!` | 不保存退出 |

### 导航

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| 上下左右 | `h` `j` `k` `l` | 移动光标 |
| 跳到行首 | `0` | 移动到行首 |
| 跳到行尾 | `$` | 移动到行尾 |
| 跳到文件开头 | `gg` | 移动到文件第一行 |
| 跳到文件结尾 | `G` | 移动到文件最后一行 |
| 向下翻页 | `<Ctrl+F>` | 向下翻一页 |
| 向上翻页 | `<Ctrl+B>` | 向上翻一页 |

### 编辑

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| 进入插入模式 | `i` | 在光标前插入 |
| 在行尾插入 | `A` | 在行尾插入 |
| 删除字符 | `x` | 删除光标下的字符 |
| 删除行 | `dd` | 删除当前行 |
| 复制行 | `yy` | 复制当前行 |
| 粘贴 | `p` | 在光标后粘贴 |
| 撤销 | `u` | 撤销上一步操作 |
| 重做 | `<Ctrl+R>` | 重做 |

## 快捷键参考

### VSCode-like 快捷键

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 查找文件 | `<Ctrl+P>` | 打开 Telescope 查找文件 |
| 全局搜索 | `<Leader>fg` | 在当前项目中搜索文本 |
| 文件资源管理器 | `<Ctrl+B>` | 打开/关闭 nvim-tree |
| Git 改动视图 | `<Ctrl+G>` | 打开 Diffview（右侧显示改动文件） |
| 终端 | `<Ctrl+`>` | 打开/关闭浮动终端 |
| 保存 | `<Ctrl+S>` | 保存文件 |
| 命令面板 | `<Ctrl+Shift+P>` | 打开 Telescope 命令 |

### 窗口管理

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 切换到左窗口 | `<Ctrl+H>` | 切换到左侧窗口 |
| 切换到下窗口 | `<Ctrl+J>` | 切换到下方窗口 |
| 切换到上窗口 | `<Ctrl+K>` | 切换到上方窗口 |
| 切换到右窗口 | `<Ctrl+L>` | 切换到右侧窗口 |
| 垂直分割 | `<Ctrl+W> v` | 垂直分割窗口 |
| 水平分割 | `<Ctrl+W> s` | 水平分割窗口 |
| 关闭窗口 | `<Ctrl+W> c` | 关闭当前窗口 |

### 缓冲区管理（标签页）

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 下一个缓冲区 | `<Shift+L>` | 切换到下一个文件标签 |
| 上一个缓冲区 | `<Shift+H>` | 切换到上一个文件标签 |
| 关闭缓冲区 | `<Leader>bd` | 关闭当前文件标签 |
| 查看所有缓冲区 | `<Leader>fb` | 使用 Telescope 查看所有打开的文件 |

### LSP 代码导航

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 跳转到定义 | `gd` | 跳转到函数/变量定义 |
| 跳转到引用 | `gr` | 查看所有引用 |
| 跳转到实现 | `gI` | 跳转到实现 |
| 查看文档 | `K` | 显示悬停文档 |
| 重命名 | `<Leader>rn` | 重命名符号 |
| 代码操作 | `<Leader>ca` | 显示代码操作菜单 |
| 格式化 | `<Leader>f` | 格式化代码 |
| 显示诊断 | `<Leader>d` | 显示当前行诊断信息 |
| 上一个诊断 | `[d` | 跳到上一个错误/警告 |
| 下一个诊断 | `]d` | 跳到下一个错误/警告 |

### 文件资源管理器 (nvim-tree)

在文件资源管理器窗口中：

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 打开/关闭目录 | `<Enter>` | 展开或折叠目录 |
| 打开文件 | `<Enter>` | 打开选中文件 |
| 新建文件 | `a` | 添加新文件 |
| 新建目录 | `A` | 添加新目录 |
| 删除 | `d` | 删除文件或目录 |
| 重命名 | `r` | 重命名文件或目录 |
| 刷新 | `R` | 刷新文件树 |
| 显示帮助 | `g?` | 显示所有快捷键 |

### Telescope 搜索

在 Telescope 窗口中：

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 选择 | `<Enter>` | 打开选中项 |
| 向下移动 | `<Ctrl+J>` / `<Down>` | 移动到下一个选项 |
| 向上移动 | `<Ctrl+K>` / `<Up>` | 移动到上一个选项 |
| 关闭 | `<Esc>` / `<Ctrl+C>` | 关闭 Telescope |
| 预览滚动下 | `<Ctrl+D>` | 向下滚动预览 |
| 预览滚动上 | `<Ctrl+U>` | 向上滚动预览 |

### Git 集成

#### Gitsigns（代码内显示）

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 下一个修改 | `]c` | 跳到下一个 git hunk |
| 上一个修改 | `[c` | 跳到上一个 git hunk |
| 暂存 hunk | `<Leader>hs` | 暂存当前修改 |
| 撤销 hunk | `<Leader>hr` | 撤销当前修改 |
| 预览 hunk | `<Leader>hp` | 预览当前修改 |
| 显示 blame | `<Leader>hb` | 显示当前行 blame |

#### Diffview（VSCode-like Changes 视图）

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 打开 Git 改动视图 | `<Ctrl+G>` | 打开 Diffview，右侧显示所有修改的文件 |
| 打开 Git 改动视图 | `<Leader>go` | 打开 Diffview，右侧显示所有修改的文件 |
| 关闭 Git 视图 | `<Leader>gc` | 关闭 Diffview |
| 刷新 Git 视图 | `<Leader>gr` | 刷新 Diffview |
| 文件历史 | `<Leader>gh` | 查看文件提交历史 |

**Diffview 操作说明（类似 VSCode 的 Changes 视图）:**

在 Diffview 界面中：
- 右侧文件面板显示所有有改动的文件
- 使用 `j/k` 或方向键在文件列表中移动
- 按 `Enter` 或 `o` 打开选中文件的 diff 比较
- 按 `-` 暂存/取消暂存当前文件
- 按 `S` 暂存所有文件
- 按 `U` 取消暂存所有文件
- 按 `X` 恢复文件到之前的状态
- 按 `Tab` 切换到下一个文件
- 按 `gf` 在编辑器中打开文件
- 按 `?` 查看所有快捷键帮助

### 终端 (toggleterm)

在终端模式中：

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 打开/关闭终端 | `<Ctrl+`>` | 切换浮动终端 |
| 退出终端模式 | `<Esc>` | 回到普通模式 |
| 切换窗口 | `<Ctrl+H/J/K/L>` | 在窗口间切换 |

### 注释 (Comment.nvim)

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 切换行注释 | `gcc` | 注释/取消注释当前行 |
| 切换块注释 | `gbc` | 注释/取消注释块 |
| 可视化模式注释 | `gc` | 注释选中区域 |

## 插件列表

### UI 增强

| 插件名 | 功能描述 |
|--------|----------|
| `vscode.nvim` | VSCode 风格的主题 |
| `lualine.nvim` | 状态栏 |
| `bufferline.nvim` | 缓冲区标签页 |
| `nvim-tree.lua` | 文件资源管理器 |
| `alpha-nvim` | 启动页 |
| `dressing.nvim` | 更好的输入/选择 UI |
| `noice.nvim` | 美化消息、命令行 |
| `indent-blankline.nvim` | 缩进引导线 |

### 代码编辑

| 插件名 | 功能描述 |
|--------|----------|
| `nvim-cmp` | 自动补全引擎 |
| `LuaSnip` | 代码片段 |
| `nvim-lspconfig` | LSP 配置 |
| `mason.nvim` | LSP/DAP 管理器 |
| `conform.nvim` | 代码格式化 |
| `nvim-treesitter` | 语法高亮 |
| `nvim-autopairs` | 自动括号补全 |
| `Comment.nvim` | 代码注释 |
| `nvim-surround` | 包围字符操作 |

### 搜索和导航

| 插件名 | 功能描述 |
|--------|----------|
| `telescope.nvim` | 模糊查找 |
| `trouble.nvim` | 诊断列表 |
| `vim-illuminate` | 相同单词高亮 |
| `todo-comments.nvim` | TODO 高亮 |

### 工具

| 插件名 | 功能描述 |
|--------|----------|
| `gitsigns.nvim` | Git 集成（代码内显示改动） |
| `diffview.nvim` | Git diff 查看器（VSCode-like Changes 视图） |
| `toggleterm.nvim` | 终端 |
| `which-key.nvim` | 快捷键提示 |
| `nvim-web-devicons` | 文件图标 |

## LSP 配置

### 已配置的 LSP 服务器

- **clangd** - C/C++ 语言支持
- **pyright** - Python 语言支持
- **lua_ls** - Lua 语言支持
- **jsonls** - JSON 语言支持

### 安装新的 LSP 服务器

使用 Mason 安装：

```vim
:Mason
```

在打开的界面中：
- 按 `i` 安装
- 按 `u` 更新
- 按 `X` 卸载

### LSP 快捷键

| 快捷键 | 功能 |
|--------|------|
| `gd` | 跳转到定义 |
| `gr` | 查找引用 |
| `K` | 显示文档 |
| `<Leader>rn` | 重命名 |
| `<Leader>ca` | 代码操作 |
| `<Leader>f` | 格式化 |

## 自定义配置

### 配置文件结构

```
~/.config/nvim/
├── init.lua                 # 入口文件
├── lua/
│   ├── options.lua          # 基础选项配置
│   ├── keymaps.lua          # 快捷键配置
│   └── plugins/             # 插件配置
│       ├── colorscheme.lua
│       ├── lualine.lua
│       ├── nvim-tree.lua
│       ├── telescope.lua
│       ├── lsp.lua
│       ├── completion.lua
│       ├── treesitter.lua
│       ├── formatting.lua
│       ├── comment.lua
│       ├── autopairs.lua
│       ├── gitsigns.lua
│       ├── diffview.lua
│       ├── toggleterm.lua
│       ├── bufferline.lua
│       ├── which-key.lua
│       ├── indent-blankline.lua
│       ├── alpha.lua
│       ├── trouble.lua
│       ├── illuminate.lua
│       ├── todo-comments.lua
│       ├── surround.lua
│       ├── cursorline.lua
│       ├── dressing.lua
│       ├── noice.lua
│       ├── devicons.lua
│       ├── ts-context-commentstring.lua
│       ├── lsp-file-operations.lua
│       └── neodev.lua
```

### 添加新的插件

在 `~/.config/nvim/lua/plugins/` 目录下创建新的 Lua 文件：

```lua
-- ~/.config/nvim/lua/plugins/my-plugin.lua
return {
  {
    "作者/插件名",
    config = function()
      require("插件名").setup({
        -- 插件配置
      })
    end,
  },
}
```

### 修改快捷键

编辑 `~/.config/nvim/lua/keymaps.lua` 文件添加或修改快捷键：

```lua
-- 添加新的快捷键
vim.keymap.set("n", "<Leader>键", ":命令<CR>", { desc = "描述" })
```

### 修改基础选项

编辑 `~/.config/nvim/lua/options.lua` 文件：

```lua
-- 修改缩进为 4 个空格
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
```

### 重新加载配置

修改配置后，在 Neovim 中执行：

```vim
:source %           " 重新加载当前文件
:Lazy reload <插件名>  " 重新加载指定插件
```

或者直接重启 Neovim。

## 故障排除

### 1. 插件安装失败

**问题**：首次启动时插件下载失败。

**解决**：
```vim
:Lazy sync
```

### 2. LSP 无法工作

**问题**：代码提示、跳转等功能不可用。

**解决**：
1. 确认 LSP 已安装：`:Mason`
2. 检查 LSP 状态：`:LspInfo`
3. 安装对应语言的 LSP：在 Mason 界面按 `i` 安装

### 3. Treesitter 高亮异常

**问题**：语法高亮不正常。

**解决**：
```vim
:TSUpdate
```

### 4. 快捷键冲突

**问题**：某些快捷键不起作用。

**解决**：
1. 检查终端设置
2. 检查是否有其他程序占用了快捷键
3. 使用 `:verbose map <快捷键>` 查看按键映射

### 5. 性能问题

**问题**：Neovim 运行缓慢。

**解决**：
1. 禁用不必要的插件
2. 检查启动时间：
   ```bash
   nvim --startuptime startup.log
   ```
3. 使用 `:Lazy profile` 查看插件加载时间

### 6. 配置文件错误

**问题**：Neovim 启动报错。

**解决**：
1. 检查语法错误：
   ```bash
   nvim -c 'lua require("config")'
   ```
2. 查看错误信息，定位到具体文件
3. 检查括号、引号是否匹配

## 常用命令参考

### 文件操作

```vim
:e <文件名>          " 打开文件
:w                   " 保存
:q                   " 退出
:wq 或 :x            " 保存并退出
:q!                  " 强制退出
:qa                  " 退出所有窗口
:wqa                 " 保存所有并退出
```

### 搜索替换

```vim
/<pattern>           " 向下搜索
?<pattern>           " 向上搜索
n                    " 下一个匹配
N                    " 上一个匹配
:%s/old/new/g        " 全局替换
:%s/old/new/gc       " 全局替换（确认）
```

### 窗口管理

```vim
:split 或 :sp        " 水平分割
:vsplit 或 :vsp      " 垂直分割
:close               " 关闭窗口
:only                " 只保留当前窗口
```

### 缓冲区管理

```vim
:ls                  " 列出所有缓冲区
:b <编号>            " 切换到指定缓冲区
:bd                  " 删除当前缓冲区
:bn                  " 下一个缓冲区
:bp                  " 上一个缓冲区
```

## 学习资源

- [Neovim 官方文档](https://neovim.io/doc/)
- [Vim 教程](https://www.openvim.com/)
- [Vim Adventures](https://vim-adventures.com/) - 游戏化学习 Vim
- [Awesome Neovim](https://github.com/rockerBOO/awesome-neovim) - Neovim 资源合集

## 反馈与支持

如有问题或建议，请在项目中提交 Issue。

---

**最后更新**: 2024年
