#!/usr/bin/env bash
# ==============================================================================
#  setup_remote_server.sh
#  远程服务器环境一键配置
#
#  完成:
#    1) zsh + oh-my-zsh + Dracula + 插件 (离线 bootstrap)
#    2) AutoGoo 所需的 conda goo 环境 (tar.gz 解压 或 yml 重建)
#    3) 写入 .vscode/settings.json 指向该环境
#
#  用法:
#    ./setup_remote_server.sh [options]
#
#  选项:
#    --skip-zsh              跳过 zsh 配置
#    --skip-conda            跳过 conda goo 环境安装
#    --skip-vscode           跳过 .vscode/settings.json 写入
#    --skip-conda-init       跳过 conda init 写入 ~/.zshrc.local
#    --make-default-shell    把 zsh 设为默认登录 shell (需要 chsh)
#    --from-yaml PATH        从 yml 重建 conda env (而非 tar.gz 解压)
#                            配套: workspace/tools/dotfiles-env/goo-environment.yml
#    --dry-run               只打印要执行的命令, 不实际运行
#    --help                  显示帮助
#
#  环境变量 (覆盖默认值):
#    CONDA_PKG_PATH          conda 环境压缩包路径 (tar.gz) 或 yml 路径
#    CONDA_TARGET_DIR        anaconda envs 的父目录
#    CONDA_ENV_NAME          环境名 (默认 goo)
#    PROJECT_DIR             主项目目录 (默认 AutoGoo)
#    DOTFILES_ZSH_DIR        dotfiles-zsh 路径
#    DOTFILES_ENV_DIR        dotfiles-env 路径 (含 goo-environment.yml)
#    LOG_FILE                日志路径 (默认 $HOME/.setup_remote_server.log,
#                             不可写时回退 /tmp/setup_remote_server.<user>.log)
# ==============================================================================
# ==============================================================================
set -euo pipefail

# -------- defaults (overridable via env) -------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONDA_PKG_PATH="${CONDA_PKG_PATH:-}"   # 空: yml 模式; 非空: tar.gz 模式 (或显式 .yml/.yaml 后缀)
CONDA_TARGET_DIR="${CONDA_TARGET_DIR:-$DEFAULT_REPO_ROOT/anaconda}"
CONDA_ENV_NAME="${CONDA_ENV_NAME:-goo}"
PROJECT_DIR="${PROJECT_DIR:-$DEFAULT_REPO_ROOT/AutoGoo}"
DOTFILES_ZSH_DIR="${DOTFILES_ZSH_DIR:-$SCRIPT_DIR/dotfiles-zsh}"
DOTFILES_ENV_DIR="${DOTFILES_ENV_DIR:-$SCRIPT_DIR/dotfiles-env}"
# 日志默认放 $HOME: 跨机器可写, 不依赖共享挂载点的权限
LOG_FILE="${LOG_FILE:-$HOME/.setup_remote_server.log}"

# -------- flag parsing -------------------------------------------------------
SKIP_ZSH=0
SKIP_CONDA=0
SKIP_VSCODE=0
SKIP_CONDA_INIT=0
MAKE_DEFAULT_SHELL=0
DRY_RUN=0
FROM_YAML=""

print_help() {
  sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-zsh)            SKIP_ZSH=1 ;;
    --skip-conda)          SKIP_CONDA=1 ;;
    --skip-vscode)         SKIP_VSCODE=1 ;;
    --skip-conda-init)     SKIP_CONDA_INIT=1 ;;
    --make-default-shell)  MAKE_DEFAULT_SHELL=1 ;;
    --from-yaml)           shift; FROM_YAML="${1:-}" ;;
    --from-yaml=*)         FROM_YAML="${1#--from-yaml=}" ;;
    --dry-run)             DRY_RUN=1 ;;
    --help|-h)             print_help ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run with --help for usage." >&2
      exit 2
      ;;
  esac
  shift
done

# -------- helpers ------------------------------------------------------------
_ts() { date '+%Y-%m-%d %H:%M:%S'; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

log() {
  printf '[%s] %s\n' "$(_ts)" "$*" | tee -a "$LOG_FILE"
}

# run_shell <shell-cmd>   用 eval 执行 shell 字符串; --dry-run 时只打印
run_shell() {
  if [[ "$DRY_RUN" = "1" ]]; then
    log "[DRY-RUN] $*"
  else
    log "[RUN] $*"
    eval "$@"
  fi
}

require_path() {
  local p="$1"
  local label="$2"
  if [[ ! -e "$p" ]]; then
    log "[FAIL] $label 不存在: $p"
    return 1
  fi
  log "[OK]   $label: $p"
  return 0
}

# -------- preflight ----------------------------------------------------------
# 选一个能写的日志位置: 优先 $LOG_FILE, 回退 $HOME, 再回退 /tmp
pick_log_file() {
  local candidate="$1"
  local dir
  dir="$(dirname "$candidate")"
  if mkdir -p "$dir" 2>/dev/null && [[ -w "$dir" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

if ! pick_log_file "$LOG_FILE"; then
  if pick_log_file "$HOME/.setup_remote_server.log"; then
    LOG_FILE="$HOME/.setup_remote_server.log"
    echo "[WARN] 指定日志路径不可写, 回退到 $LOG_FILE" >&2
  else
    LOG_FILE="/tmp/setup_remote_server.${USER:-$$}.log"
    echo "[WARN] HOME 也不可写, 回退到 $LOG_FILE" >&2
  fi
fi

mkdir -p "$(dirname "$LOG_FILE")"
: > "$LOG_FILE"

log "==== setup_remote_server start ===="
log "SCRIPT_DIR        = $SCRIPT_DIR"
log "CONDA_PKG_PATH    = $CONDA_PKG_PATH"
log "CONDA_TARGET_DIR  = $CONDA_TARGET_DIR"
log "CONDA_ENV_NAME    = $CONDA_ENV_NAME"
log "PROJECT_DIR       = $PROJECT_DIR"
log "DOTFILES_ZSH_DIR  = $DOTFILES_ZSH_DIR"
log "DRY_RUN           = $DRY_RUN"

if ! have_cmd bash; then
  log "[FAIL] bash 不存在, 无法继续"
  exit 1
fi
if ! have_cmd tar; then
  log "[FAIL] tar 不存在, 无法继续"
  exit 1
fi

# -------- step 1: zsh -------------------------------------------------------
if [[ "$SKIP_ZSH" = "0" ]]; then
  log "==== [1/4] zsh (offline bootstrap) ===="
  if ! require_path "$DOTFILES_ZSH_DIR" "dotfiles-zsh 目录"; then
    log "      提示: 设置 DOTFILES_ZSH_DIR 指向正确目录"
    exit 1
  fi
  if ! require_path "$DOTFILES_ZSH_DIR/packages" "dotfiles-zsh/packages (离线包)"; then
    log "      提示: 先在有网机器运行 prepare-offline-packages.sh 准备 bundles"
    exit 1
  fi
  if ! require_path "$DOTFILES_ZSH_DIR/bootstrap-offline.sh" "bootstrap-offline.sh"; then
    exit 1
  fi

  if have_cmd zsh \
      && [[ -d "$HOME/.oh-my-zsh" ]] \
      && [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]] \
      && [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]] \
      && [[ -d "$HOME/.oh-my-zsh/custom/themes/dracula" ]]; then
    log "[SKIP] zsh / oh-my-zsh / Dracula / 插件 已就绪"
  else
    run_shell "OFFLINE=1 bash '$DOTFILES_ZSH_DIR/bootstrap-offline.sh'"
  fi

  if [[ -x "$HOME/.local/zsh-5.9/bin/zsh" ]]; then
    ZSH_BIN="$HOME/.local/zsh-5.9/bin/zsh"
  else
    ZSH_BIN="$(command -v zsh 2>/dev/null || echo zsh)"
  fi
  log "[OK] zsh bin = $ZSH_BIN ($(${ZSH_BIN} --version 2> /dev/null || echo unknown))"

  # 确保 ~/.bashrc 里有 zsh 的 PATH 导出 (chsh 失败/无 root 时 fallback)
  ZSH_BIN_DIR="$(dirname "$ZSH_BIN")"
  if [[ -d "$ZSH_BIN_DIR" && "$ZSH_BIN_DIR" != "." ]]; then
    BASHRC_FILE="${BASHRC_FILE:-$HOME/.bashrc}"
    PATH_LINE="export PATH=\"$ZSH_BIN_DIR:\$PATH\""
    if [[ ! -f "$BASHRC_FILE" ]]; then
      if [[ "$DRY_RUN" = "1" ]]; then
        log "[DRY-RUN] touch $BASHRC_FILE"
      else
        touch "$BASHRC_FILE"
      fi
    fi
    # 检查 zsh bin 目录是否已经在任何 export PATH= 行里
    # 允许 $HOME/zsh/bin / /home/x/zsh/bin / $PREFIX/zsh/bin 等多种写法
    ZSH_BIN_REL="${ZSH_BIN_DIR#$HOME}"  # $HOME 下的相对路径, 例如 /zsh/bin
    ZSH_BIN_NAME="$(basename "$ZSH_BIN_DIR")"      # bin
    ZSH_BIN_PARENT="$(basename "$(dirname "$ZSH_BIN_DIR")")"  # zsh
    PATH_LINES="$(grep -E '^[[:space:]]*export[[:space:]]+PATH=' "$BASHRC_FILE" 2>/dev/null || true)"
    if [[ -n "$PATH_LINES" ]] \
        && { echo "$PATH_LINES" | grep -Fq "$ZSH_BIN_DIR"; } 2>/dev/null; then
      log "[SKIP] $BASHRC_FILE 已包含 zsh PATH 导出 (检测到 $ZSH_BIN_DIR)"
    elif [[ -n "$PATH_LINES" ]] \
        && [[ -n "$ZSH_BIN_REL" ]] \
        && { echo "$PATH_LINES" | grep -Fq "\$HOME$ZSH_BIN_REL" || echo "$PATH_LINES" | grep -Fq "\${HOME}$ZSH_BIN_REL"; } 2>/dev/null; then
      log "[SKIP] $BASHRC_FILE 已包含 zsh PATH 导出 (检测到 \$HOME$ZSH_BIN_REL)"
    elif [[ -n "$PATH_LINES" ]] \
        && [[ "$ZSH_BIN_NAME" == "bin" ]] \
        && { echo "$PATH_LINES" | grep -Fq "/$ZSH_BIN_PARENT/bin"; } 2>/dev/null; then
      log "[SKIP] $BASHRC_FILE 已包含 /$ZSH_BIN_PARENT/bin (匹配 zsh bin 模式)"
    elif grep -Fqx "$PATH_LINE" "$BASHRC_FILE" 2>/dev/null; then
      log "[SKIP] $BASHRC_FILE 已包含精确 zsh PATH 导出"
    else
      if [[ "$DRY_RUN" = "1" ]]; then
        log "[DRY-RUN] echo '$PATH_LINE' >> $BASHRC_FILE"
      else
        {
          echo ""
          echo "# zsh installation (setup_remote_server.sh)"
          echo "$PATH_LINE"
        } >> "$BASHRC_FILE"
        log "[OK]   追加 zsh PATH 导出到 $BASHRC_FILE"
      fi
    fi
  fi

  if [[ "$MAKE_DEFAULT_SHELL" = "1" ]]; then
    if have_cmd chsh; then
      run_shell "chsh -s '$ZSH_BIN'"
    else
      log "[WARN] chsh 不可用, 跳过默认 shell 设置"
    fi
  else
    log "[HINT] 设为默认 shell: ./setup_remote_server.sh --make-default-shell"
  fi
else
  log "==== [1/4] zsh (skipped) ===="
fi

# -------- step 2: conda goo env ----------------------------------------------
if [[ "$SKIP_CONDA" = "0" ]]; then
  # Detect yml mode: --from-yaml 显式给出, 或 CONDA_PKG_PATH 以 .yml/.yaml 结尾
  YML_MODE=0
  YML_PATH=""
  if [[ -n "$FROM_YAML" ]]; then
    YML_MODE=1; YML_PATH="$FROM_YAML"
  elif [[ "$CONDA_PKG_PATH" == *.yml || "$CONDA_PKG_PATH" == *.yaml ]]; then
    YML_MODE=1; YML_PATH="$CONDA_PKG_PATH"
  fi

  if [[ "$YML_MODE" = "1" ]]; then
    log "==== [2/4] conda goo 环境 (yml 重建) ===="
  else
    log "==== [2/4] conda goo 环境 (tar.gz 解压) ===="
  fi

  if [[ "$YML_MODE" = "0" ]]; then
    if ! require_path "$CONDA_PKG_PATH" "conda 环境压缩包"; then
      log "      提示: 设置 CONDA_PKG_PATH 指向正确的 tar.gz, 或用 --from-yaml 改走 yml 重建"
      exit 1
    fi
  fi
  if ! require_path "$PROJECT_DIR" "AutoGoo 项目"; then
    log "      提示: 设置 PROJECT_DIR 指向项目根目录"
    exit 1
  fi

  ENV_PATH="$CONDA_TARGET_DIR/envs/$CONDA_ENV_NAME"

  if [[ "$YML_MODE" = "0" ]]; then
    # md5 校验 (仅 tar.gz 模式)
    if [[ -f "${CONDA_PKG_PATH}.md5" ]]; then
      EXPECTED_MD5="$(awk '{print $1}' "${CONDA_PKG_PATH}.md5")"
      ACTUAL_MD5="$(md5sum "$CONDA_PKG_PATH" | awk '{print $1}')"
      if [[ "$EXPECTED_MD5" != "$ACTUAL_MD5" ]]; then
        log "[FAIL] md5 不匹配: 期望 $EXPECTED_MD5, 实际 $ACTUAL_MD5"
        exit 1
      fi
      log "[OK]   md5 校验通过 ($ACTUAL_MD5)"
    else
      log "[WARN] 未找到 ${CONDA_PKG_PATH}.md5, 跳过完整性校验"
    fi
  fi

  if [[ -f "$ENV_PATH/.conda_unpack_done" || -d "$ENV_PATH/bin" ]]; then
    log "[SKIP] conda 环境已就绪: $ENV_PATH"
  else
    if [[ "$YML_MODE" = "1" ]]; then
      if ! require_path "$YML_PATH" "conda env yml"; then
        log "      提示: 设置 --from-yaml 或 CONDA_PKG_PATH 指向正确的 yml (默认: \$SCRIPT_DIR/dotfiles-env/goo-environment.yml)"
        exit 1
      fi
      if have_cmd conda; then
        run_shell "conda env create -f '$YML_PATH' -n '$CONDA_ENV_NAME' -p '$ENV_PATH'"
      else
        log "[FAIL] conda 不可用, 无法走 yml 重建路径"
        log "      提示: 先在 ~/.bashrc 里初始化 conda, 或用 CONDA_PKG_PATH 指向 tar.gz 走解压路径"
        exit 1
      fi
    else
      run_shell "mkdir -p '$ENV_PATH'"
      run_shell "tar -xzf '$CONDA_PKG_PATH' -C '$ENV_PATH'"
      if [[ -x "$ENV_PATH/bin/conda-unpack" ]]; then
        run_shell "'$ENV_PATH/bin/conda-unpack'"
      else
        log "[WARN] 未找到 $ENV_PATH/bin/conda-unpack, 跳过 unpacking"
      fi
    fi
    if [[ "$DRY_RUN" = "0" ]]; then
      touch "$ENV_PATH/.conda_unpack_done"
    fi
  fi

  if have_cmd conda; then
    if conda config --show envs_dirs 2>/dev/null | grep -Fxq "  - $CONDA_TARGET_DIR/envs"; then
      log "[SKIP] conda envs_dirs 已包含 $CONDA_TARGET_DIR/envs"
    else
      run_shell "conda config --append envs_dirs '$CONDA_TARGET_DIR/envs'"
    fi
  else
    log "[WARN] conda 不可用, 请先在 ~/.bashrc 里初始化 conda"
  fi
else
  log "==== [2/4] conda (skipped) ===="
fi

# -------- step 3: vscode interpreter ----------------------------------------
if [[ "$SKIP_VSCODE" = "0" ]]; then
  log "==== [3/4] .vscode/settings.json ===="
  if [[ -d "$PROJECT_DIR" ]]; then
    ENV_PATH="$CONDA_TARGET_DIR/envs/$CONDA_ENV_NAME"
    mkdir -p "$PROJECT_DIR/.vscode"
    SETTINGS_FILE="$PROJECT_DIR/.vscode/settings.json"

    if [[ -f "$SETTINGS_FILE" ]] && grep -q "$CONDA_ENV_NAME/bin/python" "$SETTINGS_FILE"; then
      log "[SKIP] $SETTINGS_FILE 已配置 $CONDA_ENV_NAME 解释器"
    else
      SETTINGS_BODY=$(cat <<EOF
{
  "python.defaultInterpreterPath": "$ENV_PATH/bin/python",
  "python.terminal.activateEnvironment": true
}
EOF
)
      if [[ "$DRY_RUN" = "1" ]]; then
        log "[DRY-RUN] cat > $SETTINGS_FILE <<EOF"
        log "$SETTINGS_BODY"
      else
        printf '%s\n' "$SETTINGS_BODY" > "$SETTINGS_FILE"
        log "[OK]   写入 $SETTINGS_FILE"
      fi
    fi
  else
    log "[SKIP] $PROJECT_DIR 不存在"
  fi
else
  log "==== [3/4] vscode (skipped) ===="
fi

# -------- step 4: conda init in ~/.zshrc.local --------------------------------
if [[ "$SKIP_CONDA_INIT" = "0" ]]; then
  log "==== [4/4] conda init in ~/.zshrc.local ===="

  # 探测 conda: 优先 CONDA_TARGET_DIR 下的 base, 再 PATH, 再常见位置
  CONDA_BIN=""
  for candidate in \
      "$CONDA_TARGET_DIR/bin/conda" \
      "$HOME/anaconda/bin/conda" \
      "$HOME/miniforge3/bin/conda" \
      "$HOME/miniconda3/bin/conda" \
      "$HOME/miniconda/bin/conda"
  do
    if [[ -x "$candidate" ]]; then
      CONDA_BIN="$candidate"
      break
    fi
  done
  if [[ -z "$CONDA_BIN" ]] && have_cmd conda; then
    CONDA_BIN="$(command -v conda)"
  fi

  if [[ -z "$CONDA_BIN" ]]; then
    log "[WARN] 找不到 conda, 跳过 init"
    log "      提示: 先安装 miniconda / anaconda / miniforge, 或设置 CONDA_TARGET_DIR"
  else
    CONDA_BASE="$(cd "$(dirname "$(dirname "$CONDA_BIN")")" && pwd)"
    log "[OK] conda bin = $CONDA_BIN"
    log "[OK] conda base = $CONDA_BASE"

    ZSHRC_LOCAL="$HOME/.zshrc.local"
    touch "$ZSHRC_LOCAL"

    if grep -Fq "# >>> conda initialize >>>" "$ZSHRC_LOCAL"; then
      log "[SKIP] $ZSHRC_LOCAL 已包含 conda initialize 块"
    else
      CONDA_INIT_BLOCK=$(cat <<EOF

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="\$('$CONDA_BIN' 'shell.zsh' 'hook' 2> /dev/null)"
if [ \$? -eq 0 ]; then
    eval "\$__conda_setup"
else
    if [ -f "$CONDA_BASE/etc/profile.d/conda.sh" ]; then
        . "$CONDA_BASE/etc/profile.d/conda.sh"
    else
        export PATH="$CONDA_BASE/bin:\$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
EOF
)
      if [[ "$DRY_RUN" = "1" ]]; then
        log "[DRY-RUN] append to $ZSHRC_LOCAL:"
        log "$CONDA_INIT_BLOCK"
      else
        printf '%s\n' "$CONDA_INIT_BLOCK" >> "$ZSHRC_LOCAL"
        log "[OK]   追加 conda init 到 $ZSHRC_LOCAL"
      fi
    fi

    # 提示: ~/.zshrc 是否会自动 source .zshrc.local
    if [[ -f "$HOME/.zshrc" ]] && ! grep -Fq ".zshrc.local" "$HOME/.zshrc"; then
      log "[HINT] 你的 ~/.zshrc 不会自动 source ~/.zshrc.local"
      log "      在 ~/.zshrc 末尾添加:  [[ -f \$HOME/.zshrc.local ]] && source \$HOME/.zshrc.local"
    fi
  fi
else
  log "==== [4/4] conda init (skipped) ===="
fi

# -------- summary ------------------------------------------------------------
log "==== done ===="
log "激活 conda 环境:  conda activate $CONDA_ENV_NAME"
log "Python 解释器:    $CONDA_TARGET_DIR/envs/$CONDA_ENV_NAME/bin/python"
if [[ "$SKIP_ZSH" = "0" && "$MAKE_DEFAULT_SHELL" = "0" ]]; then
  log "切换到 zsh:       exec ${ZSH_BIN:-zsh}  (或重新登录)"
fi
log "日志:             $LOG_FILE"
