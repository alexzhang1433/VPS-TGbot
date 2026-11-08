#!/bin/bash

APP_DIR="/opt/tg_multi_bot"
SERVICE_NAME="tg_multi_bot"
SCRIPT_NAME="host_bot.py"
SCRIPT_URL="https://raw.githubusercontent.com/alexzhang1433/VPS-TGbot/refs/heads/main/host_bot.py"
DATABASE_URL="https://raw.githubusercontent.com/alexzhang1433/VPS-TGbot/refs/heads/main/database.py"

function check_and_install() {
  PKG=$1
  if ! dpkg -s "$PKG" >/dev/null 2>&1; then
    echo "📦 安装 $PKG ..."
    apt update -qq >/dev/null 2>&1
    apt install -y -qq "$PKG" >/dev/null 2>&1
  else
    echo "✅ 已安装 $PKG，跳过"
  fi
}

function check_python_version() {
  if command -v python3.11 >/dev/null 2>&1; then
    PYTHON_CMD="python3.11"
    echo "✅ 已安装 Python 3.11+，使用 $PYTHON_CMD"
    return 0
  elif command -v python3.12 >/dev/null 2>&1; then
    PYTHON_CMD="python3.12"
    echo "✅ 已安装 Python 3.12+，使用 $PYTHON_CMD"
    return 0
  elif command -v python3.13 >/dev/null 2>&1; then
    PYTHON_CMD="python3.13"
    echo "✅ 已安装 Python 3.13+，使用 $PYTHON_CMD"
    return 0
  elif command -v python3 >/dev/null 2>&1; then
    CURRENT_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
    MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
    
    if [ "$MAJOR" -ge 3 ] && [ "$MINOR" -ge 11 ]; then
      PYTHON_CMD="python3"
      echo "✅ 当前 Python 版本 $CURRENT_VERSION 满足要求"
      return 0
    else
      echo "⚠️ 当前 Python 版本 $CURRENT_VERSION 低于 3.11，需要升级"
      return 1
    fi
  else
    echo "⚠️ 未检测到 Python，需要安装"
    return 1
  fi
}

function install_python311() {
  echo "📦 开始安装 Python 3.11 ..."
  apt update -qq >/dev/null 2>&1
  apt install -y -qq software-properties-common >/dev/null 2>&1
  
  if command -v add-apt-repository >/dev/null 2>&1; then
    add-apt-repository ppa:deadsnakes/ppa -y >/dev/null 2>&1
    apt update -qq >/dev/null 2>&1
  fi
  
  apt install -y -qq python3.11 python3.11-venv python3.11-dev >/dev/null 2>&1
  
  if command -v python3.11 >/dev/null 2>&1; then
    PYTHON_CMD="python3.11"
    echo "✅ Python 3.11 安装成功"
  else
    echo "❌ Python 3.11 安装失败，请手动安装"
    exit 1
  fi
}

function setup_github_backup() {
  echo ""
  echo "============================"
  echo "   GitHub 自动备份配置"
  echo "============================"
  echo ""
  
  if ! command -v git >/dev/null 2>&1; then
    echo "📦 安装 Git..."
    check_and_install git
  else
    echo "✅ Git 已安装"
  fi
  
  read -p "🔐 请输入 GitHub 用户名: " GH_USERNAME
  if [ -z "$GH_USERNAME" ]; then
    echo "❌ 用户名不能为空"
    return 1
  fi
  
  read -p "📦 请输入 GitHub 私有仓库名 (例: tg-bot-backup): " GH_REPO
  if [ -z "$GH_REPO" ]; then
    echo "❌ 仓库名不能为空"
    return 1
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📘 如何获取 GitHub Personal Access Token"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "1️⃣  访问 GitHub Settings -> Developer settings -> Personal access tokens -> Tokens (classic)"
  echo "2️⃣  勾选权限（Scopes）：✅ repo (完整仓库访问权限)"
  echo "3️⃣  复制生成的 Token"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  read -p "🔑 请输入 GitHub Personal Access Token: " GH_TOKEN
  if [ -z "$GH_TOKEN" ]; then
    echo "❌ Token 不能为空"
    return 1
  fi
  
  # 创建备份脚本（修复 set -e 导致的 git diff 返回 1 退出 Bug）
  cat <<'BACKUP_SCRIPT' > "$APP_DIR/backup.sh"
#!/bin/bash

APP_DIR="/opt/tg_multi_bot"
BACKUP_DIR="$APP_DIR/backup_temp"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

# 加载环境变量
if [ -f "$APP_DIR/.env" ]; then
  source "$APP_DIR/.env"
else
  echo "❌ 未找到 .env 文件"
  exit 1
fi

if [ -z "$GH_USERNAME" ] || [ -z "$GH_REPO" ] || [ -z "$GH_TOKEN" ]; then
  echo "❌ GitHub 配置缺失，请检查 .env 文件"
  exit 1
fi

mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"

if [ ! -d ".git" ]; then
  git init -b main >/dev/null 2>&1
  git config user.name "TG Bot Backup"
  git config user.email "backup@bot.local"
  git remote add origin "https://$GH_TOKEN@github.com/$GH_USERNAME/$GH_REPO.git" 2>/dev/null || \
  git remote set-url origin "https://$GH_TOKEN@github.com/$GH_USERNAME/$GH_REPO.git"
fi

echo "📦 备份数据文件..."
[ -f "$APP_DIR/bot_data.db" ] && cp -f "$APP_DIR/bot_data.db" . && echo "  ✅ bot_data.db（数据库）"

echo "⚙️ 备份配置文件..."
cp -f "$APP_DIR/.env" . 2>/dev/null || echo "# Empty" > .env

echo "📜 备份脚本文件..."
cp -f "$APP_DIR/host_bot.py" . 2>/dev/null || touch host_bot.py
cp -f "$APP_DIR/database.py" . 2>/dev/null && echo "  ✅ database.py"

cat <<EOF > backup_info.txt
备份时间: $DATE
服务器: $(hostname)
Python版本: $(python3 --version 2>&1)
EOF

git add .
# 使用 set +e 块确保 git diff 无改动时不崩脚本
set +e
git diff --cached --quiet
DIFF_STATUS=$?
set -e

if [ $DIFF_STATUS -eq 0 ]; then
  echo "✅ 数据无变化，跳过备份推送"
  if [ -z "$SILENT_BACKUP" ] && [ -n "$MANAGER_TOKEN" ] && [ -n "$ADMIN_CHANNEL" ]; then
    curl -s -X POST "https://api.telegram.org/bot$MANAGER_TOKEN/sendMessage" \
      -d chat_id="$ADMIN_CHANNEL" \
      -d text="📦 自动备份提醒%0A%0A⏰ 时间: $DATE%0A📊 状态: 数据无变化%0A📂 仓库: $GH_USERNAME/$GH_REPO" \
      >/dev/null 2>&1
  fi
else
  git commit -m "自动备份 - $DATE" >/dev/null 2>&1
  git push -f origin main >/dev/null 2>&1
  
  if [ $? -eq 0 ]; then
    echo "✅ 备份成功推送到 GitHub ($DATE)"
    if [ -z "$SILENT_BACKUP" ] && [ -n "$MANAGER_TOKEN" ] && [ -n "$ADMIN_CHANNEL" ]; then
      curl -s -X POST "https://api.telegram.org/bot$MANAGER_TOKEN/sendMessage" \
        -d chat_id="$ADMIN_CHANNEL" \
        -d text="✅ 自动备份成功%0A%0A⏰ 时间: $DATE%0A📂 仓库: $GH_USERNAME/$GH_REPO%0A📦 状态: 已推送到 GitHub" \
        >/dev/null 2>&1
    fi
  else
    echo "❌ 推送失败，请检查 GitHub Token 权限"
    if [ -z "$SILENT_BACKUP" ] && [ -n "$MANAGER_TOKEN" ] && [ -n "$ADMIN_CHANNEL" ]; then
      curl -s -X POST "https://api.telegram.org/bot$MANAGER_TOKEN/sendMessage" \
        -d chat_id="$ADMIN_CHANNEL" \
        -d text="❌ 自动备份失败%0A%0A⏰ 时间: $DATE%0A📂 仓库: $GH_USERNAME/$GH_REPO%0A⚠️ 原因: GitHub 推送失败" \
        >/dev/null 2>&1
    fi
    exit 1
  fi
fi
BACKUP_SCRIPT

  chmod +x "$APP_DIR/backup.sh"
  
  # 写入 .env
  if grep -q "^GH_USERNAME=" "$APP_DIR/.env" 2>/dev/null; then
    sed -i '/^# GitHub 自动备份配置/d' "$APP_DIR/.env"
    sed -i '/^GH_USERNAME=/d' "$APP_DIR/.env"
    sed -i '/^GH_REPO=/d' "$APP_DIR/.env"
    sed -i '/^GH_TOKEN=/d' "$APP_DIR/.env"
  fi
  
  cat <<EOF >> "$APP_DIR/.env"

# GitHub 自动备份配置
GH_USERNAME=$GH_USERNAME
GH_REPO=$GH_REPO
GH_TOKEN=$GH_TOKEN
EOF

  setup_restore_script

  # 检查远程是否有备份
  TEMP_CHECK_DIR="/tmp/tg_backup_check_$$"
  if git clone --depth 1 -q "https://$GH_TOKEN@github.com/$GH_USERNAME/$GH_REPO.git" "$TEMP_CHECK_DIR" 2>/dev/null; then
    if [ -f "$TEMP_CHECK_DIR/bot_data.db" ] || [ -f "$TEMP_CHECK_DIR/backup_info.txt" ]; then
      echo "✅ 发现远程备份数据！"
      [ -f "$TEMP_CHECK_DIR/backup_info.txt" ] && cat "$TEMP_CHECK_DIR/backup_info.txt"
      
      read -p "❓ 是否从 GitHub 恢复备份数据？[y/N]: " RESTORE_CONFIRM
      if [[ "$RESTORE_CONFIRM" =~ ^[Yy]$ ]]; then
        systemctl stop "$SERVICE_NAME.service" 2>/dev/null || true
        [ -f "$APP_DIR/bot_data.db" ] && cp -f "$APP_DIR/bot_data.db" "$APP_DIR/backup_before_restore_$(date +%Y%m%d_%H%M%S)/" 2>/dev/null || true
        [ -f "$TEMP_CHECK_DIR/bot_data.db" ] && cp -f "$TEMP_CHECK_DIR/bot_data.db" "$APP_DIR/"
        systemctl start "$SERVICE_NAME.service" 2>/dev/null || true
        echo "✅ 数据恢复完成！"
      fi
    fi
    rm -rf "$TEMP_CHECK_DIR"
  fi

  # 配置 crontab
  CRON_CMD="59 23 * * * TZ='Asia/Shanghai' $APP_DIR/backup.sh >> $APP_DIR/backup.log 2>&1"
  (crontab -l 2>/dev/null | grep -v "$APP_DIR/backup.sh"; echo "$CRON_CMD") | crontab -
  echo "✅ 已设置每日 23:59 自动备份（中国时间 UTC+8）"
}

function setup_restore_script() {
  cat <<'RESTORE_SCRIPT' > "$APP_DIR/restore.sh"
#!/bin/bash
set -e

APP_DIR="/opt/tg_multi_bot"
BACKUP_DIR="$APP_DIR/backup_temp"
SERVICE_NAME="tg_multi_bot"

if [ -f "$APP_DIR/.env" ]; then
  source "$APP_DIR/.env"
else
  echo "❌ 未找到 .env 文件"
  exit 1
fi

echo "============================"
echo "   从 GitHub 恢复备份"
echo "============================"

echo "📥 从 GitHub 拉取备份数据..."
mkdir -p "$BACKUP_DIR"
if [ -d "$BACKUP_DIR/.git" ]; then
  cd "$BACKUP_DIR"
  git fetch origin >/dev/null 2>&1 || true
  git reset --hard origin/main >/dev/null 2>&1 || true
else
  rm -rf "$BACKUP_DIR"
  git clone -b main "https://$GH_TOKEN@github.com/$GH_USERNAME/$GH_REPO.git" "$BACKUP_DIR" >/dev/null 2>&1 || {
    echo "❌ 克隆远程仓库失败，请检查 Token 或仓库是否存在"
    exit 1
  }
  cd "$BACKUP_DIR"
fi

[ -f "$BACKUP_DIR/backup_info.txt" ] && cat "$BACKUP_DIR/backup_info.txt"

echo "1) 仅恢复数据文件 (bot_data.db)"
echo "2) 恢复数据库 + 配置文件 (.env)"
echo "3) 恢复全部"
echo "0) 取消操作"
read -p "请选择 [0-3]: " R_OPT

case "$R_OPT" in
  0) exit 0 ;;
  1) R_DATA=true; R_ENV=false; R_SCR=false ;;
  2) R_DATA=true; R_ENV=true; R_SCR=false ;;
  3) R_DATA=true; R_ENV=true; R_SCR=true ;;
  *) echo "❌ 无效选择"; exit 1 ;;
esac

read -p "确认恢复并覆盖当前数据？[y/N]: " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo "❌ 已取消" && exit 0

systemctl stop "$SERVICE_NAME.service" 2>/dev/null || true

BACKUP_OLD_DIR="$APP_DIR/backup_before_restore_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_OLD_DIR"
cp -f "$APP_DIR/bot_data.db" "$APP_OLD_DIR/" 2>/dev/null || true

[ "$R_DATA" = true ] && [ -f "$BACKUP_DIR/bot_data.db" ] && cp -f "$BACKUP_DIR/bot_data.db" "$APP_DIR/"
[ "$R_ENV" = true ] && [ -f "$BACKUP_DIR/.env" ] && cp -f "$BACKUP_DIR/.env" "$APP_DIR/"
[ "$R_SCR" = true ] && [ -f "$BACKUP_DIR/host_bot.py" ] && cp -f "$BACKUP_DIR/host_bot.py" "$APP_DIR/"

systemctl start "$SERVICE_NAME.service"
rm -rf "$BACKUP_DIR"
echo "✅ 恢复完成，服务已重启！"
RESTORE_SCRIPT
  chmod +x "$APP_DIR/restore.sh"
}

function install_bot() {
  echo "📦 检查系统依赖..."
  check_and_install git
  check_and_install curl
  
  if ! check_python_version; then
    install_python311
  fi
  
  if [[ "$PYTHON_CMD" == "python3.11" ]]; then
    check_and_install python3.11-venv
  elif [[ "$PYTHON_CMD" == "python3.12" ]]; then
    check_and_install python3.12-venv
  elif [[ "$PYTHON_CMD" == "python3.13" ]]; then
    check_and_install python3.13-venv
  else
    check_and_install python3-venv
  fi

  mkdir -p "$APP_DIR"
  cd "$APP_DIR"

  echo "📥 下载项目文件..."
  curl -sL -o "$SCRIPT_NAME" "$SCRIPT_URL" || { echo "❌ host_bot.py 下载失败"; exit 1; }
  curl -sL -o "database.py" "$DATABASE_URL" || { echo "❌ database.py 下载失败"; exit 1; }

  echo "🐍 创建虚拟环境..."
  [ -d venv ] && [ ! -f venv/bin/activate ] && rm -rf venv
  
  if [ ! -d venv ]; then
    $PYTHON_CMD -m venv venv || { echo "❌ 虚拟环境创建失败"; exit 1; }
  fi
  
  source venv/bin/activate
  pip install --upgrade pip -q >/dev/null 2>&1
  pip install -q "python-telegram-bot==20.7" python-dotenv

  while true; do
      read -p "请输入宿主 Bot 的 Token: " MANAGER_TOKEN
      [ -n "$MANAGER_TOKEN" ] && break
      echo "❌ Token 不能为空"
  done

  while true; do
      read -p "请输入宿主 TG_CHAT_ID (管理员ID/频道ID): " ADMIN_CHANNEL
      [ -n "$ADMIN_CHANNEL" ] && break
      echo "❌ ID 不能为空"
  done

  cat <<EOF > .env
MANAGER_TOKEN=$MANAGER_TOKEN
ADMIN_CHANNEL=$ADMIN_CHANNEL
EOF

  cat <<EOF >/etc/systemd/system/$SERVICE_NAME.service
[Unit]
Description=Telegram Multi Bot Host
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python $APP_DIR/$SCRIPT_NAME
Restart=always
RestartSec=3
EnvironmentFile=$APP_DIR/.env

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload >/dev/null 2>&1
  systemctl enable "$SERVICE_NAME.service" >/dev/null 2>&1
  systemctl restart "$SERVICE_NAME.service" >/dev/null 2>&1

  echo ""
  read -p "📦 是否配置 GitHub 自动备份？[y/N]: " SETUP_BACKUP
  if [[ "$SETUP_BACKUP" =~ ^[Yy]$ ]]; then
    setup_github_backup
  fi
  
  echo "✅ 部署完成！"
}

function uninstall_bot() {
  systemctl stop "$SERVICE_NAME.service" >/dev/null 2>&1 || true
  systemctl disable "$SERVICE_NAME.service" >/dev/null 2>&1 || true
  rm -f "/etc/systemd/system/$SERVICE_NAME.service"
  systemctl daemon-reload >/dev/null 2>&1

  crontab -l 2>/dev/null | grep -v "$APP_DIR/backup.sh" | crontab - 2>/dev/null || true
  rm -rf "$APP_DIR"
  echo "✅ 卸载完成！"
}

while true; do
  echo ""
  echo "============================"
  echo "   Telegram 多 Bot 管理脚本"
  echo "   双向 机器人 自用托管平台    "
  echo "============================"
  echo "1) 安装 Bot 管理平台"
  echo "2) 卸载 Bot 管理平台"
  echo "3) 配置 GitHub 自动备份"
  echo "4) 手动执行备份"
  echo "5) 从 GitHub 恢复备份"
  echo "6) 返回 VIP 工具箱"
  echo "7) 退出"
  echo "============================"
  read -p "请选择操作 [1-7]: " choice

  case "$choice" in
    1) install_bot ;;
    2) uninstall_bot ;;
    3) [ -d "$APP_DIR" ] && setup_github_backup || echo "❌ 请先安装平台" ;;
    4) [ -f "$APP_DIR/backup.sh" ] && "$APP_DIR/backup.sh" || echo "❌ 备份脚本不存在" ;;
    5) [ -f "$APP_DIR/restore.sh" ] && "$APP_DIR/restore.sh" || echo "❌ 恢复脚本不存在" ;;
    6) bash <(curl -Ls https://raw.githubusercontent.com/ryty1/Checkin/refs/heads/main/vip.sh); exit 0 ;;
    7) echo "👋 感谢使用！"; exit 0 ;;
    *) echo "❌ 无效选择，请输入 1-7" ;;
  esac
done
