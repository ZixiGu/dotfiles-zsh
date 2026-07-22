#!/usr/bin/env bash
# ==============================================================================
#  bootstrap-remote.sh
#  新机器"一行命令"装 Goo 环境
#
#  用法:
#    # 一行命令 (从 GitHub raw 拉)
#    curl -fsSL https://raw.githubusercontent.com/ZixiGu/dotfiles-zsh/main/bootstrap-remote.sh | \
#        bash -s -- --github-pat <TOKEN> --secrets-from user@old-host
#
#    # 或本地文件跑
#    bash bootstrap-remote.sh --github-pat <TOKEN> --secrets-from user@host
#
#  选项:
#    --github-pat TOKEN      GitHub PAT (含 repo scope) for dotfiles-env PRIVATE 仓
#                            也支持环境变量 GITHUB_PAT
#    --secrets-from HOST     从 user@host scp 拉 secrets.env
#                            也支持环境变量 SECRETS_FROM_HOST
#    --secrets-path PATH     远端 secrets.env 路径 (默认 ~/.config/secrets.env)
#    --skip-timer            跳过 systemd timer 装
#    --dry-run               只打印不执行
#    --help                  显示帮助
#
#  它会做什么:
#    [0/8] 准备路径 (workspace/tools, ~/.local/bin)
#    [1/8] 检查 prereq (bash/curl/git/tar/zsh)
#    [2/8] 装 miniforge3 (如果没)
#    [3/8] clone dotfiles-zsh (PUBLIC)
#    [4/8] clone dotfiles-env (PRIVATE, 用 PAT 或 SSH key)
#    [5/8] 装 Node CLI (claude/codex/ccswitch via npm i -g)
#    [6/8] 装 secrets.env (从远端 scp 或本地 cp, chmod 600)
#    [7/8] 重建 conda env (用 yml, 10~20 分钟)
#    [8/8] 装 systemd timer (每天 06:30 backup)
#
#  提示:
#    - 跑完会自动 exec zsh -l 并跑 goo-env check
#    - 任何 step 失败可重跑, 已完成的 step 会跳过 (幂等)
# ==============================================================================
set -euo pipefail

# -------- 参数解析 ------------------------------------------------------------
GITHUB_PAT="${GITHUB_PAT:-}"
SECRETS_FROM_HOST="${SECRETS_FROM_HOST:-}"
SECRETS_PATH="${SECRETS_PATH:-}"
SKIP_TIMER=0
DRY_RUN="${DRY_RUN:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --github-pat)     shift; GITHUB_PAT="${1:-}" ;;
        --github-pat=*)   GITHUB_PAT="${1#--github-pat=}" ;;
        --secrets-from)   shift; SECRETS_FROM_HOST="${1:-}" ;;
        --secrets-from=*) SECRETS_FROM_HOST="${1#--secrets-from=}" ;;
        --secrets-path)   shift; SECRETS_PATH="${1:-~/.config/secrets.env}" ;;
        --secrets-path=*) SECRETS_PATH="${1#--secrets-path=}" ;;
        --skip-timer)     SKIP_TIMER=1 ;;
        --dry-run)        DRY_RUN=1 ;;
        --help|-h)
            sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run with --help for usage." >&2
            exit 2
            ;;
    esac
    shift
done

# -------- 颜色 ----------------------------------------------------------------
if [[ -t 1 ]]; then
    C_OK="\033[32m"; C_WARN="\033[33m"; C_FAIL="\033[31m"
    C_INFO="\033[36m"; C_BOLD="\033[1m"; C_RESET="\033[0m"
else
    C_OK=""; C_WARN=""; C_FAIL=""; C_INFO=""; C_BOLD=""; C_RESET=""
fi

_ts() { date '+%Y-%m-%d %H:%M:%S'; }
log_info()  { printf "${C_INFO}INFO${C_RESET}  %s\n" "$*"; }
log_ok()    { printf "${C_OK}OK${C_RESET}    %s\n" "$*"; }
log_warn()  { printf "${C_WARN}WARN${C_RESET}  %s\n" "$*"; }
log_fail()  { printf "${C_FAIL}FAIL${C_RESET}  %s\n" "$*"; }
log_bold()  { printf "${C_BOLD}%s${C_RESET}\n" "$*"; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }
die() { log_fail "$*"; exit 1; }

run_shell() {
    if [[ "$DRY_RUN" = "1" ]]; then
        log_info "[DRY-RUN] $*"
    else
        log_info "[RUN] $*"
        eval "$@"
    fi
}

# -------- 路径 ----------------------------------------------------------------
HOME_DIR="$HOME"
WORKSPACE_DIR="$HOME_DIR/workspace"
TOOLS_DIR="$WORKSPACE_DIR/tools"
DOTFILES_ZSH_DIR="$TOOLS_DIR/dotfiles-zsh"
DOTFILES_ENV_DIR="$TOOLS_DIR/dotfiles-env"
LOCAL_BIN="$HOME_DIR/.local/bin"
LOCAL_NODE_MODULES="$HOME_DIR/.local/lib/node_modules"
ZIXIGU_ZSH_REPO="https://github.com/ZixiGu/dotfiles-zsh.git"
ZIXIGU_ENV_REPO="https://github.com/ZixiGu/dotfiles-env.git"
SECRETS_FILE="$HOME_DIR/.config/secrets.env"
YML_PATH="$DOTFILES_ENV_DIR/goo-environment.yml"
SETUP_SCRIPT="$DOTFILES_ZSH_DIR/setup_remote_server.sh"

# -------- 头部输出 ------------------------------------------------------------
log_bold "Goo 环境 bootstrap (新机器一条龙)"
echo
log_info "  HOME          = $HOME_DIR"
log_info "  DOTFILES_ZSH  = $ZIXIGU_ZSH_REPO"
log_info "  DOTFILES_ENV  = $ZIXIGU_ENV_REPO"
if [[ -n "$SECRETS_FROM_HOST" ]]; then
    log_info "  SECRETS_FROM  = $SECRETS_FROM_HOST:${SECRETS_PATH:-~/.config/secrets.env}"
elif [[ -n "$GITHUB_PAT" ]]; then
    log_info "  GITHUB_PAT    = (set, 长度 ${#GITHUB_PAT})"
fi
echo

# -------- 0. 准备路径 ---------------------------------------------------------
log_info "[0/8] 准备路径..."
run_shell "mkdir -p '$WORKSPACE_DIR' '$TOOLS_DIR' '$HOME_DIR/.local/bin' '$HOME_DIR/.config'"

# -------- 1. prereq -----------------------------------------------------------
log_info "[1/8] 检查 prereq..."
for c in bash curl git tar zsh; do
    if have_cmd "$c"; then
        log_ok "  $c"
    else
        log_fail "  $c 缺失"
        die "缺少 prereq: $c (用 apt/yum/dnf 装)"
    fi
done

# -------- 2. miniforge3 ------------------------------------------------------
log_info "[2/8] 检查 miniforge3..."
conda_base=""
for candidate in "$HOME_DIR/miniforge3" "$HOME_DIR/anaconda" "$HOME_DIR/miniconda3" \
    "/home/zj/miniforge3" "/home/zj/anaconda" "/opt/miniforge3" "/opt/anaconda"; do
    if [[ -x "$candidate/bin/conda" ]]; then
        conda_base="$candidate"
        break
    fi
done
if [[ -x "$conda_base/bin/conda" ]]; then
    log_ok "  conda 已就绪: $conda_base"
else
    log_info "  装 miniforge3 -> $HOME_DIR/miniforge3"
    run_shell "curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -o /tmp/Miniforge3.sh"
    run_shell "bash /tmp/Miniforge3.sh -b -p '$HOME_DIR/miniforge3'"
    run_shell "rm -f /tmp/Miniforge3.sh"
    conda_base="$HOME_DIR/miniforge3"
    log_ok "  miniforge3 装好: $conda_base"
fi

# -------- 3. clone dotfiles-zsh (PUBLIC) -------------------------------------
log_info "[3/8] clone dotfiles-zsh (PUBLIC)..."
if [[ -d "$DOTFILES_ZSH_DIR/.git" ]]; then
    log_ok "  dotfiles-zsh 已存在: $DOTFILES_ZSH_DIR"
else
    run_shell "git clone '$ZIXIGU_ZSH_REPO' '$DOTFILES_ZSH_DIR'"
fi
if [[ ! -L "$HOME_DIR/.zshrc" ]]; then
    run_shell "ln -sf '$DOTFILES_ZSH_DIR/.zshrc' '$HOME_DIR/.zshrc'"
fi

# -------- 4. clone dotfiles-env (PRIVATE) ------------------------------------
log_info "[4/8] clone dotfiles-env (PRIVATE)..."
if [[ -d "$DOTFILES_ENV_DIR/.git" ]]; then
    log_ok "  dotfiles-env 已存在: $DOTFILES_ENV_DIR"
else
    env_url="$ZIXIGU_ENV_REPO"
    if [[ -n "$GITHUB_PAT" ]]; then
        env_url="https://x-access-token:${GITHUB_PAT}@github.com/ZixiGu/dotfiles-env.git"
        log_info "  用 GitHub PAT clone (长度 ${#GITHUB_PAT})"
    elif ssh -T -o BatchMode=yes -o ConnectTimeout=3 git@github.com 2>&1 | grep -q 'successfully authenticated'; then
        env_url="git@github.com:ZixiGu/dotfiles-env.git"
        log_info "  用 SSH key clone"
    else
        log_warn "  未提供 --github-pat 且 SSH key 未配; 跳过 clone (env 重建会失败)"
        log_warn "  解决: 重跑时加 --github-pat <TOKEN>"
    fi
    if [[ "$DRY_RUN" != "1" ]]; then
        git clone "$env_url" "$DOTFILES_ENV_DIR" || log_warn "  clone 失败, 跳到下一步"
    else
        log_info "  [DRY-RUN] git clone $env_url $DOTFILES_ENV_DIR"
    fi
fi

# -------- 5. Node CLI --------------------------------------------------------
log_info "[5/8] Node CLI..."
if [[ ! -d "$LOCAL_NODE_MODULES/@anthropic-ai" ]]; then
    if have_cmd npm; then
        run_shell "npm install -g @anthropic-ai/claude-code @openai/codex ccswitch"
    else
        log_warn "  npm 不在 PATH, 跳过; 需手工装 Node.js + npm"
    fi
else
    log_ok "  node_modules 已就绪"
fi
for cli in claude:@anthropic-ai/claude-code/bin/claude.exe codex:@openai/codex/bin/codex.js ccswitch:ccswitch/dist/cli.js; do
    name="${cli%%:*}"
    rel="${cli#*:}"
    if [[ ! -e "$LOCAL_BIN/$name" ]]; then
        if [[ -e "$LOCAL_NODE_MODULES/$rel" ]]; then
            run_shell "ln -sf '$LOCAL_NODE_MODULES/$rel' '$LOCAL_BIN/$name'"
        else
            log_warn "  $name 目标不存在: $LOCAL_NODE_MODULES/$rel (需手工装)"
        fi
    fi
done

# -------- 6. secrets.env -----------------------------------------------------
log_info "[6/8] secrets.env..."
if [[ -f "$SECRETS_FILE" ]]; then
    mode=$(stat -c '%a' "$SECRETS_FILE")
    if [[ "$mode" == "600" ]]; then
        log_ok "  secrets.env 已就绪: mode=600"
    else
        log_warn "  secrets.env 存在但 mode=$mode, 修正中..."
        run_shell "chmod 600 '$SECRETS_FILE'"
    fi
elif [[ -n "$SECRETS_FROM_HOST" ]]; then
    # 兼容 "user@host" 或 "user@host:path"
    scp_src="$SECRETS_FROM_HOST"
    if [[ "$scp_src" != *:* ]]; then
        scp_src="$scp_src:${SECRETS_PATH:-~/.config/secrets.env}"
    fi
    run_shell "scp '$scp_src' '$SECRETS_FILE'"
    run_shell "chmod 600 '$SECRETS_FILE'"
    log_ok "  secrets.env 从 $scp_src 拉到 $SECRETS_FILE"
else
    log_warn "  secrets.env 不存在, 跳过"
    log_warn "  解决: 重跑时加 --secrets-from user@host"
    log_warn "  缺 secrets.env 不影响 env 重建, 但 claude/codex wrapper 读不到 key"
fi

# -------- 7. 重建 conda env -------------------------------------------------
log_info "[7/8] 重建 conda env..."
if [[ ! -f "$YML_PATH" ]]; then
    log_fail "  yml 不存在: $YML_PATH"
    log_fail "  dotfiles-env clone 可能失败; 检查上一步"
else
    if [[ -f "$SETUP_SCRIPT" ]]; then
        run_shell "bash '$SETUP_SCRIPT' --from-yaml '$YML_PATH' --skip-zsh --skip-conda-init"
    else
        log_warn "  未找到 $SETUP_SCRIPT, 跳过重建"
    fi
fi

# -------- 8. timer -----------------------------------------------------------
log_info "[8/8] systemd timer..."
if [[ "$SKIP_TIMER" = "1" ]]; then
    log_info "  --skip-timer 跳过"
else
    # timer 装需要 conda base 已就绪且 systemctl 可用
    if have_cmd systemctl; then
        SERVICE_FILE="$HOME_DIR/.config/systemd/user/goo-env-backup.service"
        TIMER_FILE="$HOME_DIR/.config/systemd/user/goo-env-backup.timer"
        mkdir -p "$HOME_DIR/.config/systemd/user"

        cat > "$SERVICE_FILE" <<'EOF'
[Unit]
Description=Goo environment daily backup
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'source "__CONDA_BASE__/etc/profile.d/conda.sh" 2>/dev/null && exec __LOCAL_BIN__/goo-env backup'
WorkingDirectory=__HOME__
EOF
        sed -i "s|__CONDA_BASE__|$conda_base|g; s|__LOCAL_BIN__|$LOCAL_BIN|g; s|__HOME__|$HOME_DIR|g" "$SERVICE_FILE"

        cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Goo environment daily backup timer

[Timer]
OnCalendar=*-*-* 06:30:00
Persistent=true
Unit=goo-env-backup.service

[Install]
WantedBy=timers.target
EOF

        run_shell "systemctl --user daemon-reload"
        run_shell "systemctl --user enable --now goo-env-backup.timer"
        log_ok "  timer 装上, 每天 06:30 跑 backup"
    else
        log_warn "  systemctl 不在 PATH, 跳过 timer 装"
    fi
fi

# -------- 收尾 ---------------------------------------------------------------
echo
log_bold "Bootstrap 完成"
log_info "下一步:  exec zsh -l"
log_info "验证:    goo-env check    (应 12 OK / 0 FAIL)"
log_info "一屏:    goo-env status"
echo
if [[ "$DRY_RUN" != "1" && -t 0 ]]; then
    read -r -p "exec zsh -l 现在? [Y/n] " ans
    if [[ -z "$ans" || "$ans" =~ ^[Yy] ]]; then
        exec zsh -l
    fi
fi
