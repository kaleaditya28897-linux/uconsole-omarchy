#!/bin/bash
# =============================================================================
# uConsole Omarchy - Development Environment Setup
# Terminal, shell, editor, and dev tools configuration
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

USERNAME="cyber"
USER_HOME="/home/${USERNAME}"

[ "$EUID" -ne 0 ] && error "Run as root"

# =============================================================================
# Install Development Tools
# =============================================================================
log "Installing development tools..."

pacman -S --noconfirm --needed \
    neovim \
    tmux \
    zsh \
    starship \
    fzf \
    ripgrep \
    fd \
    bat \
    eza \
    zoxide \
    git \
    git-delta \
    lazygit \
    github-cli \
    jq \
    yq \
    htop \
    btop \
    ncdu \
    tree \
    unzip \
    p7zip \
    wget \
    curl \
    rsync \
    openssh

# =============================================================================
# Programming Languages
# =============================================================================
log "Installing programming language support..."

pacman -S --noconfirm --needed \
    python \
    python-pip \
    python-virtualenv \
    nodejs \
    npm \
    go \
    rust \
    lua \
    luarocks

# =============================================================================
# Shell Configuration (Zsh)
# =============================================================================
log "Configuring Zsh..."

# Change default shell
chsh -s /bin/zsh ${USERNAME}

mkdir -p ${USER_HOME}/.config/zsh

cat > ${USER_HOME}/.zshrc << 'ZSHRC'
# =============================================================================
# uConsole Omarchy - Zsh Configuration
# =============================================================================

# History
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY

# Options
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt CORRECT
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

# Completion
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Vi mode
bindkey -v
export KEYTIMEOUT=1

# Key bindings
bindkey '^P' up-line-or-history
bindkey '^N' down-line-or-history
bindkey '^R' history-incremental-search-backward
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^W' backward-kill-word

# Environment
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export MANPAGER="nvim +Man!"
export BROWSER="firefox"

# XDG Base Directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# Path
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"

# Aliases
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first'
alias lt='eza -T --icons --level=2'
alias la='eza -a --icons'

alias cat='bat --style=plain'
alias grep='rg'
alias find='fd'

alias v='nvim'
alias vim='nvim'
alias vi='nvim'

alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -10'
alias gd='git diff'
alias lg='lazygit'

alias t='tmux'
alias ta='tmux attach'
alias tn='tmux new -s'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias cls='clear'
alias q='exit'
alias :q='exit'

# System shortcuts
alias sdn='sudo shutdown now'
alias reboot='sudo reboot'
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias search='pacman -Ss'
alias remove='sudo pacman -Rns'
alias cleanup='sudo pacman -Rns $(pacman -Qdtq)'

# uConsole specific
alias bat-status='uconsole-battery-monitor'
alias wifi='nmtui'
alias bt='bluetuith'
alias lte='modem status'
alias net='netstat-all'

# Functions
mkcd() { mkdir -p "$1" && cd "$1"; }
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.tar.xz)  tar xJf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.7z)      7z x "$1" ;;
            *)         echo "'$1' cannot be extracted" ;;
        esac
    fi
}

# FZF
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --color=bg+:#1a1b26,bg:#1a1b26,spinner:#7aa2f7,hl:#7aa2f7
  --color=fg:#c0caf5,header:#7aa2f7,info:#bb9af7,pointer:#7aa2f7
  --color=marker:#9ece6a,fg+:#c0caf5,prompt:#bb9af7,hl+:#7aa2f7
'

# Zoxide
eval "$(zoxide init zsh)"

# Starship prompt
eval "$(starship init zsh)"
ZSHRC

# Starship configuration
mkdir -p ${USER_HOME}/.config

cat > ${USER_HOME}/.config/starship.toml << 'STARSHIP'
# Minimal starship prompt for uConsole

format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$python\
$nodejs\
$rust\
$golang\
$cmd_duration\
$line_break\
$character"""

[character]
success_symbol = "[>](bold green)"
error_symbol = "[>](bold red)"
vimcmd_symbol = "[<](bold green)"

[username]
show_always = false
format = "[$user]($style)@"
style_user = "bold blue"

[hostname]
ssh_only = true
format = "[$hostname]($style):"
style = "bold green"

[directory]
truncation_length = 3
truncate_to_repo = true
format = "[$path]($style)[$read_only]($read_only_style) "
style = "bold cyan"

[git_branch]
format = "[$branch]($style) "
style = "bold purple"

[git_status]
format = '([$all_status$ahead_behind]($style) )'
style = "bold yellow"

[python]
format = '[py:$version]($style) '
style = "yellow"

[nodejs]
format = '[node:$version]($style) '
style = "green"

[rust]
format = '[rs:$version]($style) '
style = "red"

[golang]
format = '[go:$version]($style) '
style = "cyan"

[cmd_duration]
min_time = 2_000
format = "[$duration]($style) "
style = "bold yellow"
STARSHIP

# =============================================================================
# Tmux Configuration
# =============================================================================
log "Configuring Tmux..."

cat > ${USER_HOME}/.tmux.conf << 'TMUX'
# =============================================================================
# uConsole Omarchy - Tmux Configuration
# =============================================================================

# Prefix
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# General settings
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g mouse on
set -g history-limit 50000
set -sg escape-time 0
set -g focus-events on
set -g set-clipboard on
setw -g mode-keys vi

# Status bar
set -g status-position top
set -g status-interval 1
set -g status-style "bg=#1a1b26 fg=#c0caf5"
set -g status-left-length 40
set -g status-right-length 80
set -g status-left "#[fg=#7aa2f7,bold][#S] "
set -g status-right "#[fg=#bb9af7]%H:%M #[fg=#565f89]| #[fg=#9ece6a]%d %b"

# Window status
setw -g window-status-format "#[fg=#565f89] #I:#W "
setw -g window-status-current-format "#[fg=#7aa2f7,bold] #I:#W "

# Pane borders
set -g pane-border-style "fg=#414868"
set -g pane-active-border-style "fg=#7aa2f7"

# Key bindings
bind r source-file ~/.tmux.conf \; display "Reloaded!"

# Splits
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Navigation (vim-style)
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Resize
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Windows
bind c new-window -c "#{pane_current_path}"
bind n next-window
bind p previous-window

# Copy mode
bind Enter copy-mode
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "wl-copy"
bind -T copy-mode-vi Escape send -X cancel

# Quick actions
bind g new-window -n "lazygit" lazygit
bind b new-window -n "btop" btop
TMUX

# =============================================================================
# Neovim Configuration
# =============================================================================
log "Configuring Neovim..."

mkdir -p ${USER_HOME}/.config/nvim

cat > ${USER_HOME}/.config/nvim/init.lua << 'NVIM'
-- =============================================================================
-- uConsole Omarchy - Neovim Configuration
-- Minimal, fast configuration for portable development
-- =============================================================================

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- =============================================================================
-- Options
-- =============================================================================
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8

opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true

opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

opt.splitbelow = true
opt.splitright = true

opt.wrap = false
opt.linebreak = true
opt.breakindent = true

opt.undofile = true
opt.swapfile = false
opt.backup = false

opt.updatetime = 250
opt.timeoutlen = 300

opt.termguicolors = true
opt.background = "dark"

opt.clipboard = "unnamedplus"
opt.mouse = "a"
opt.showmode = false
opt.completeopt = "menu,menuone,noselect"

-- =============================================================================
-- Keymaps
-- =============================================================================
local map = vim.keymap.set

-- Better navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to below window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to above window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Better escape
map("i", "jk", "<Esc>", { desc = "Escape" })
map("i", "kj", "<Esc>", { desc = "Escape" })

-- Clear search
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Save and quit
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
map("n", "<leader>x", "<cmd>x<CR>", { desc = "Save and quit" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- Move lines
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- Stay centered
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Better paste
map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })

-- Quickfix
map("n", "<leader>cn", "<cmd>cnext<CR>zz", { desc = "Next quickfix" })
map("n", "<leader>cp", "<cmd>cprev<CR>zz", { desc = "Prev quickfix" })

-- =============================================================================
-- Plugins
-- =============================================================================
require("lazy").setup({
    -- Colorscheme
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            require("tokyonight").setup({
                style = "night",
                transparent = true,
                terminal_colors = true,
            })
            vim.cmd.colorscheme("tokyonight")
        end,
    },

    -- File explorer
    {
        "nvim-neo-tree/neo-tree.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
        keys = {
            { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "File explorer" },
        },
        opts = {
            close_if_last_window = true,
            filesystem = {
                follow_current_file = { enabled = true },
            },
        },
    },

    -- Fuzzy finder
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
            { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
            { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
            { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help" },
            { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
            { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search buffer" },
        },
        opts = {
            defaults = {
                layout_strategy = "horizontal",
                layout_config = { height = 0.6 },
            },
        },
    },

    -- Treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = {
                    "bash", "c", "cpp", "go", "javascript", "json", "lua",
                    "markdown", "python", "rust", "typescript", "yaml",
                },
                highlight = { enable = true },
                indent = { enable = true },
            })
        end,
    },

    -- LSP
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
        },
        config = function()
            require("mason").setup()
            require("mason-lspconfig").setup({
                ensure_installed = { "lua_ls", "pyright", "gopls", "rust_analyzer" },
            })

            local lspconfig = require("lspconfig")
            local capabilities = vim.lsp.protocol.make_client_capabilities()

            -- Python
            lspconfig.pyright.setup({ capabilities = capabilities })
            -- Go
            lspconfig.gopls.setup({ capabilities = capabilities })
            -- Rust
            lspconfig.rust_analyzer.setup({ capabilities = capabilities })
            -- Lua
            lspconfig.lua_ls.setup({
                capabilities = capabilities,
                settings = {
                    Lua = {
                        diagnostics = { globals = { "vim" } },
                    },
                },
            })

            -- LSP keymaps
            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local opts = { buffer = args.buf }
                    map("n", "gd", vim.lsp.buf.definition, opts)
                    map("n", "gr", vim.lsp.buf.references, opts)
                    map("n", "K", vim.lsp.buf.hover, opts)
                    map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
                    map("n", "<leader>rn", vim.lsp.buf.rename, opts)
                    map("n", "<leader>d", vim.diagnostic.open_float, opts)
                end,
            })
        end,
    },

    -- Completion
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
        },
        config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"] = cmp.mapping.scroll_docs(4),
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<C-e>"] = cmp.mapping.abort(),
                    ["<CR>"] = cmp.mapping.confirm({ select = true }),
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                    { name = "buffer" },
                    { name = "path" },
                }),
            })
        end,
    },

    -- Git
    {
        "lewis6991/gitsigns.nvim",
        opts = {
            signs = {
                add = { text = "+" },
                change = { text = "~" },
                delete = { text = "_" },
                topdelete = { text = "-" },
                changedelete = { text = "~" },
            },
        },
    },

    -- Status line
    {
        "nvim-lualine/lualine.nvim",
        opts = {
            options = {
                theme = "tokyonight",
                component_separators = "",
                section_separators = "",
            },
            sections = {
                lualine_a = { "mode" },
                lualine_b = { "branch", "diff" },
                lualine_c = { { "filename", path = 1 } },
                lualine_x = { "diagnostics", "filetype" },
                lualine_y = { "progress" },
                lualine_z = { "location" },
            },
        },
    },

    -- Comments
    { "numToStr/Comment.nvim", opts = {} },

    -- Auto pairs
    { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },

    -- Surround
    { "kylechui/nvim-surround", event = "VeryLazy", opts = {} },

    -- Which key
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {},
    },

    -- Terminal
    {
        "akinsho/toggleterm.nvim",
        keys = {
            { "<leader>t", "<cmd>ToggleTerm<CR>", desc = "Toggle terminal" },
        },
        opts = {
            size = 15,
            direction = "horizontal",
        },
    },
}, {
    performance = {
        rtp = {
            disabled_plugins = {
                "gzip", "matchit", "matchparen", "netrwPlugin",
                "tarPlugin", "tohtml", "tutor", "zipPlugin",
            },
        },
    },
})
NVIM

# =============================================================================
# Copy configs
# =============================================================================
log "Copying configuration files..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../configs"

# Waybar
mkdir -p ${USER_HOME}/.config/waybar
cp ${CONFIG_DIR}/waybar/* ${USER_HOME}/.config/waybar/ 2>/dev/null || true

# Foot
mkdir -p ${USER_HOME}/.config/foot
cp ${CONFIG_DIR}/foot/* ${USER_HOME}/.config/foot/ 2>/dev/null || true

# Fuzzel
mkdir -p ${USER_HOME}/.config/fuzzel
cp ${CONFIG_DIR}/fuzzel/* ${USER_HOME}/.config/fuzzel/ 2>/dev/null || true

# Mako
mkdir -p ${USER_HOME}/.config/mako
cp ${CONFIG_DIR}/mako/* ${USER_HOME}/.config/mako/ 2>/dev/null || true

# =============================================================================
# Git configuration
# =============================================================================
log "Configuring Git..."

cat > ${USER_HOME}/.gitconfig << 'GITCONFIG'
[user]
    # Set your name and email
    # name = Your Name
    # email = your.email@example.com

[core]
    editor = nvim
    pager = delta

[init]
    defaultBranch = main

[pull]
    rebase = true

[push]
    autoSetupRemote = true

[fetch]
    prune = true

[delta]
    navigate = true
    light = false
    line-numbers = true
    side-by-side = false
    syntax-theme = tokyonight_night

[merge]
    conflictstyle = diff3

[diff]
    colorMoved = default

[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    lg = log --graph --oneline --all
    last = log -1 HEAD
    unstage = reset HEAD --
GITCONFIG

# =============================================================================
# Set ownership
# =============================================================================
log "Setting ownership..."
chown -R ${USERNAME}:${USERNAME} ${USER_HOME}

log "=============================================="
log "Development environment setup complete!"
log ""
log "Installed:"
log "  - Zsh with starship prompt"
log "  - Tmux with vim bindings"
log "  - Neovim with LSP, completion, fuzzy finder"
log "  - Git with delta for diffs"
log "  - CLI tools: fzf, ripgrep, fd, bat, eza, etc."
log ""
log "Next: Run ./05-install-security-tools.sh"
log "=============================================="
