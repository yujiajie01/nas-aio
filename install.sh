#!/bin/bash

# =============================================================================
# NAS 终极自动化影音管理系统 - 一键安装脚本
# 版本: v1.0.0
# 支持系统: Ubuntu 20.04+, Debian 11+, CentOS 8+
# =============================================================================

set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 全局变量
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="/opt/nas-data"
readonly LOG_FILE="/tmp/nas-install.log"
readonly BACKUP_DIR="${BASE_DIR}/backup/$(date +%Y%m%d_%H%M%S)"
readonly PROGRESS_FILE="/tmp/nas-install-progress"
readonly ROLLBACK_LOG="/tmp/nas-rollback.log"

# 安装步骤计数
TOTAL_STEPS=12
CURRENT_STEP=0

# 已安装组件追踪（用于回滚）
INSTALLED_COMPONENTS=()

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "DEBUG")
            echo -e "${PURPLE}[DEBUG]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# 错误处理
error_exit() {
    log "ERROR" "$1"
    log "ERROR" "安装失败，请检查日志文件 $LOG_FILE"
    
    # 执行回滚
    if [ "${#INSTALLED_COMPONENTS[@]}" -gt 0 ]; then
        log "INFO" "检测到部分组件已安装，开始自动回滚.."
        rollback_installation
    fi
    
    exit 1
}

# 进度条显示
show_progress() {
    local current="${1:-0}"
    local total="${2:-$TOTAL_STEPS}"
    local step_name="${3:-"初始"}"
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%% - %s${NC}" "$percent" "$step_name"
    
    # 保存进度到文件
    echo "$percent|$step_name" > "$PROGRESS_FILE"
    
    if [ "$current" -eq "$total" ]; then
        echo "" # 换行
    fi
}

# 更新进度
update_progress() {
    local step_name="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress "$CURRENT_STEP" "$TOTAL_STEPS" "$step_name"
}

# 记录已安装组件
record_installed_component() {
    local component="$1"
    INSTALLED_COMPONENTS+=("$component")
    echo "$component" >> "$ROLLBACK_LOG"
}

# 回滚机制
rollback_installation() {
    log "WARNING" "开始回滚安装.."
    
    if [ -f "$ROLLBACK_LOG" ]; then
        # 反向读取已安装组件，按安装相反的顺序回滚
        tac "$ROLLBACK_LOG" | while read -r component; do
            case "$component" in
                "docker_services")
                    log "INFO" "停止 Docker 服务..."
                    docker-compose -f docker-compose.core.yml down 2>/dev/null || true
                    docker-compose -f docker-compose.extend.yml down 2>/dev/null || true
                    ;;
                "docker_images")
                    log "INFO" "清理 Docker 镜像..."
                    docker image prune -af 2>/dev/null || true
                    ;;
                "docker_compose")
                    log "INFO" "卸载 Docker Compose..."
                    sudo rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
                    ;;
                "docker")
                    log "INFO" "卸载 Docker..."
                    sudo systemctl stop docker 2>/dev/null || true
                    sudo systemctl disable docker 2>/dev/null || true
                    ;;
                "directories")
                    log "INFO" "清理目录结构..."
                    if [ -d "$BASE_DIR" ]; then
                        sudo rm -rf "$BASE_DIR" 2>/dev/null || true
                    fi
                    ;;
                "system_packages")
                    log "INFO" "清理系统包.."
                    # 注意：不建议自动卸载系统包，可能影响其他程序
                    ;;
            esac
        done
    fi
    
    # 清理临时文件
    rm -f "$PROGRESS_FILE" "$ROLLBACK_LOG" 2>/dev/null || true
    
    log "SUCCESS" "回滚完成"
}

# 配置文件验证
validate_config() {
    local config_file="$1"
    log "INFO" "验证配置文件: $config_file"
    
    if [ ! -f "$config_file" ]; then
        log "ERROR" "配置文件不存在 $config_file"
        return 1
    fi
    
    # 检查必要的环境变量
    local required_vars=(
        "MOVIEPILOT_API_TOKEN"
        "QB_USERNAME"
        "QB_PASSWORD"
        "TRANSMISSION_USER"
        "TRANSMISSION_PASS"
    )
    
    local validation_failed=false
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$config_file" || grep -q "^${var}=$" "$config_file" || grep -q "^${var}=your_.*_here" "$config_file"; then
            log "ERROR" "配置项 $var 未设置或使用默认值"
            validation_failed=true
        fi
    done
    
    # 检查端口冲突
    local ports=(3000 8001 8096 8080 9091 8088 19035 9780 25600 25378 25533 8083)
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log "WARNING" "端口 $port 已被占用，可能导致服务冲突"
        fi
    done
    
    # 检查目录权限
    if [ -d "$BASE_DIR" ] && [ ! -w "$BASE_DIR" ]; then
        log "ERROR" "数据目录 $BASE_DIR 不可写"
        validation_failed=true
    fi
    
    if [ "$validation_failed" = true ]; then
        log "ERROR" "配置文件验证失败"
        return 1
    fi
    
    log "SUCCESS" "配置文件验证通过"
    return 0
}

# 并行拉取 Docker 镜像
pull_docker_images_parallel() {
    log "INFO" "并行拉取 Docker 镜像（这可能需要较长时间）..."
    
    cd "$SCRIPT_DIR"
    export ENV_FILE="${BASE_DIR}/config/.env"
    
    # 获取所有需要的镜像列表
    local core_images=()
    local extend_images=()
    
    # 从 docker-compose 文件中提取镜像名称
    if [ -f "docker-compose.core.yml" ]; then
        mapfile -t core_images < <(docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" config --services 2>/dev/null | while read service; do
            docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" config | grep -A 10 "$service:" | grep "image:" | awk '{print $2}' | head -1
        done | grep -v '^$')
    fi
    
    if [ -f "docker-compose.extend.yml" ]; then
        mapfile -t extend_images < <(docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" config --services 2>/dev/null | while read service; do
            docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" config | grep -A 10 "$service:" | awk '/image:/ {print $2}' | head -1
        done | grep -v '^$')
    fi
    
    local all_images=("${core_images[@]}" "${extend_images[@]}")
    local total_images=${#all_images[@]}
    
    if [ $total_images -eq 0 ]; then
        log "WARNING" "未找到需要拉取的镜像，使用传统方式"
        # 退回到传统方式
        docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" pull
        docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" pull
        return
    fi
    
    log "INFO" "找到 $total_images 个镜像需要拉取"
    
    # 创建临时目录存储并行任务 PID
    local pids_dir="/tmp/nas-pull-pids"
    mkdir -p "$pids_dir"
    
    # 并行拉取镜像（最多 4 个并发）
    local max_parallel=4
    local current_parallel=0
    local completed=0
    
    for image in "${all_images[@]}"; do
        if [ -z "$image" ] || [ "$image" = "null" ]; then
            continue
        fi
        
        # 等待并发数量减少
        while [ $current_parallel -ge $max_parallel ]; do
            sleep 1
            # 检查完成的任务
            for pid_file in "$pids_dir"/*.pid; do
                if [ -f "$pid_file" ]; then
                    local pid=$(cat "$pid_file" 2>/dev/null)
                    if ! kill -0 "$pid" 2>/dev/null; then
                        rm -f "$pid_file"
                        current_parallel=$((current_parallel - 1))
                        completed=$((completed + 1))
                        
                        # 更新进度
                        local percent=$((completed * 100 / total_images))
                        printf "\r${BLUE}[拉取镜像] %d%% (%d/%d)${NC}" "$percent" "$completed" "$total_images"
                    fi
                fi
            done
        done
        
        # 启动新的拉取任务
        {
            docker pull "$image" &>/dev/null
            echo $? > "$pids_dir/pull_$$.result"
        } &
        
        local pid=$!
        echo "$pid" > "$pids_dir/pull_$$.pid"
        current_parallel=$((current_parallel + 1))
    done
    
    # 等待所有任务完成
    while [ $current_parallel -gt 0 ]; do
        sleep 1
        for pid_file in "$pids_dir"/*.pid; do
            if [ -f "$pid_file" ]; then
                local pid=$(cat "$pid_file" 2>/dev/null)
                if ! kill -0 "$pid" 2>/dev/null; then
                    rm -f "$pid_file"
                    current_parallel=$((current_parallel - 1))
                    completed=$((completed + 1))
                    
                    local percent=$((completed * 100 / total_images))
                    printf "\r${BLUE}[拉取镜像] %d%% (%d/%d)${NC}" "$percent" "$completed" "$total_images"
                fi
            fi
        done
    done
    
    echo "" # 换行
    
    # 检查是否有失败的任务
    local failed_count=0
    for result_file in "$pids_dir"/*.result; do
        if [ -f "$result_file" ]; then
            local result=$(cat "$result_file" 2>/dev/null)
            if [ "$result" != "0" ]; then
                failed_count=$((failed_count + 1))
            fi
        fi
    done
    
    # 清理临时文件
    rm -rf "$pids_dir"
    
    if [ $failed_count -eq 0 ]; then
        log "SUCCESS" "Docker 镜像并行拉取完成"
        record_installed_component "docker_images"
    else
        log "WARNING" "$failed_count 个镜像拉取失败，将使用传统方式重试"
        # 退回到传统方式
        docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" pull
        docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" pull
        record_installed_component "docker_images"
    fi
}

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
�?                                                                             �?�?           NAS 终极自动化影音管理系统 - 一键安装脚本                        �?�?                                                                             �?�? ┌─────────────────────────────────────────────────────────────────────────�?�?�? �? 🎯 核心特�?                                                           �?�?�? �? �?全自动化流水�? 搜索 �?下载 �?整理 �?通知                           �?�?�? �? �?一站式数字生活中心: 影视、音乐、漫画、电子书                         �?�?�? �? �?PT 生态深度集�? 自动辅种、刷流、Cookie 同步                        �?�?�? �? �?极致用户体验: 统一导航�?+ 微信通知 + 多设备访�?                    �?�?�? └─────────────────────────────────────────────────────────────────────────�?�?�?                                                                             �?�? 版本: v1.0.0                                                               �?�? 支持: Ubuntu 20.04+, Debian 11+, CentOS 8+                                �?�?                                                                             �?╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检测系统信息
detect_system() {
    update_progress "检测系统信息"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_VERSION=$VERSION_ID
    else
        error_exit "无法检测系统版本"
    fi
    
    ARCH=$(uname -m)
    MEMORY=$(free -m | awk 'NR==2{printf "%.1f", $2/1024}')
    DISK_SPACE=$(df -h / | awk 'NR==2{print $4}')
    
    log "INFO" "系统信息:"
    log "INFO" "  操作系统: $OS $OS_VERSION"
    log "INFO" "  架构: $ARCH"
    log "INFO" "  内存: ${MEMORY}GB"
    log "INFO" "  可用磁盘空间: $DISK_SPACE"
}

# 检查前置条件
check_prerequisites() {
    update_progress "检查前置条件"
    
    # 检查是否为root用户
    if [[ $EUID -eq 0 ]]; then
        log "WARNING" "检测到 root 用户，建议使用普通用户执行"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # 检查内存
    if (( $(echo "$MEMORY < 4.0" | bc -l) )); then
        log "WARNING" "内存不足 4GB，部分服务可能运行缓慢"
    fi
    
    # 检查磁盘空间
    local disk_gb=$(echo "$DISK_SPACE" | sed 's/G//')
    if (( $(echo "$disk_gb < 50" | bc -l) )); then
        error_exit "磁盘空间不足 50GB，无法继续安装"
    fi
    
    # 检查网络连接
    if ! ping -c 1 google.com &> /dev/null; then
        log "WARNING" "无法连接到外网，可能影响 Docker 镜像下载"
    fi
    
    log "SUCCESS" "前置条件检查通过"
}

# 更新系统
update_system() {
    update_progress "更新系统"
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            sudo apt update && sudo apt upgrade -y
            sudo apt install -y curl wget git unzip htop iotop nethogs tree vim nano bc
            ;;
        *"CentOS"*|*"Red Hat"*)
            sudo yum update -y
            sudo yum install -y curl wget git unzip htop iotop nethogs tree vim nano bc
            ;;
        *)
            log "WARNING" "未知系统类型，跳过系统更新"
            ;;
    esac
    
    record_installed_component "system_packages"
    log "SUCCESS" "系统更新完成"
}

# 安装 Docker
install_docker() {
    update_progress "安装 Docker"
    
    if command -v docker &> /dev/null; then
        log "INFO" "Docker 已安装，跳过安装步骤"
        return
    fi
    
    # 安装 Docker
    curl -fsSL https://get.docker.com | sh
    
    # 添加用户到 docker 组
    sudo usermod -aG docker $USER
    
    # 启动 Docker 服务
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 配置 Docker 镜像加速
    sudo mkdir -p /etc/docker
    cat > /tmp/daemon.json << 'EOF'
{
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF
    sudo mv /tmp/daemon.json /etc/docker/daemon.json
    sudo systemctl restart docker
    
    record_installed_component "docker"
    log "SUCCESS" "Docker 安装完成"
}

# 安装 Docker Compose
install_docker_compose() {
    log "INFO" "安装 Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        log "INFO" "Docker Compose 已安装，跳过安装步骤"
        return
    fi
    
    # 获取最新版本号
    local latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    # 下载并安装
    sudo curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # 创建软链接
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    record_installed_component "docker_compose"
    log "SUCCESS" "Docker Compose 安装完成"
}

# 创建目录结构
setup_directories() {
    update_progress "创建目录结构"
    
    if [ -x "${SCRIPT_DIR}/setup-directories.sh" ]; then
        bash "${SCRIPT_DIR}/setup-directories.sh"
    else
        error_exit "找不到目录设置脚本 ${SCRIPT_DIR}/setup-directories.sh"
    fi
    
    record_installed_component "directories"
    log "SUCCESS" "目录结构创建完成"
}

# 生成配置文件
generate_configs() {
    update_progress "生成配置文件"
    
    # 复制示例配置文件
    if [ -f "${BASE_DIR}/config/.env.example" ]; then
        cp "${BASE_DIR}/config/.env.example" "${BASE_DIR}/config/.env"
        
        # 生成随机密码
        local moviepilot_token=$(openssl rand -hex 32)
        local emby_api_key=$(openssl rand -hex 16)
        local qb_password=$(openssl rand -base64 12)
        local transmission_password=$(openssl rand -base64 12)
        
        # 替换配置文件中的变量
        sed -i "s/your_api_token_here/$moviepilot_token/g" "${BASE_DIR}/config/.env"
        sed -i "s/your_emby_api_key_here/$emby_api_key/g" "${BASE_DIR}/config/.env"
        sed -i "s/adminpass/$qb_password/g" "${BASE_DIR}/config/.env"
        sed -i "s/password123/$transmission_password/g" "${BASE_DIR}/config/.env"
        
        # 验证配置文件
        if validate_config "${BASE_DIR}/config/.env"; then
            log "SUCCESS" "配置文件生成完成"
            log "INFO" "配置文件位置: ${BASE_DIR}/config/.env"
            log "INFO" "请根据需要修改配置参数"
        else
            error_exit "配置文件验证失败"
        fi
    else
        error_exit "找不到配置文件模板"
    fi
}

# 拉取 Docker 镜像
pull_docker_images() {
    update_progress "拉取 Docker 镜像"
    
    # 使用并行拉取函数
    pull_docker_images_parallel
}

# 启动核心服务
start_core_services() {
    update_progress "启动核心服务"
    
    cd "$SCRIPT_DIR"
    export ENV_FILE="${BASE_DIR}/config/.env"
    
    # 启动核心服务
    docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" up -d
    
    # 等待服务启动
    log "INFO" "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    check_service_status "core"
    
    record_installed_component "docker_services"
    log "SUCCESS" "核心服务启动完成"
}

# 启动扩展服务
start_extend_services() {
    update_progress "启动扩展服务"
    
    cd "$SCRIPT_DIR"
    export ENV_FILE="${BASE_DIR}/config/.env"
    
    # 启动扩展服务
    docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" up -d
    
    # 等待服务启动
    log "INFO" "等待服务启动..."
    sleep 60
    
    # 检查服务状态
    check_service_status "extend"
    
    log "SUCCESS" "扩展服务启动完成"
}

# 检查服务状态
check_service_status() {
    local service_type="$1"
    log "INFO" "检查 $service_type 服务状态.."
    
    cd "$SCRIPT_DIR"
    export ENV_FILE="${BASE_DIR}/config/.env"
    
    if [ "$service_type" = "core" ]; then
        docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" ps
    else
        docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" ps
    fi
}

# 显示安装结果
show_install_result() {
    log "SUCCESS" "NAS 自动化系统安装完成！"
    
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                          安装完成 - 服务访问地址                           ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║                                                                             ║${NC}"
    echo -e "${GREEN}║ 📊 核心服务                                                                ║${NC}"
    echo -e "${GREEN}║ ├ Homepage 导航页:    http://$(hostname -I | awk '{print $1}'):3000                   ║${NC}"
    echo -e "${GREEN}║ ├ MoviePilot 调度:    http://$(hostname -I | awk '{print $1}'):8001                   ║${NC}"
    echo -e "${GREEN}║ ├ Emby 媒体服务:    http://$(hostname -I | awk '{print $1}'):8096                   ║${NC}"
    echo -e "${GREEN}║ ├ qBittorrent 下载:   http://$(hostname -I | awk '{print $1}'):8080                   ║${NC}"
    echo -e "${GREEN}║ └ Transmission 保种:  http://$(hostname -I | awk '{print $1}'):9091                   ║${NC}"
    echo -e "${GREEN}║                                                                             ║${NC}"
    echo -e "${GREEN}║ 📚 媒体库服务                                                             ║${NC}"
    echo -e "${GREEN}║ ├ Komga 漫画库:       http://$(hostname -I | awk '{print $1}'):25600                  ║${NC}"
    echo -e "${GREEN}║ ├ Audiobookshelf:     http://$(hostname -I | awk '{print $1}'):25378                  ║${NC}"
    echo -e "${GREEN}║ ├ Navidrome 音乐:     http://$(hostname -I | awk '{print $1}'):25533                  ║${NC}"
    echo -e "${GREEN}║ └ Calibre 电子书:     http://$(hostname -I | awk '{print $1}'):8083                   ║${NC}"
    echo -e "${GREEN}║                                                                             ║${NC}"
    echo -e "${GREEN}║ 🔧 工具服务                                                                ║${NC}"
    echo -e "${GREEN}║ ├ CookieCloud:        http://$(hostname -I | awk '{print $1}'):8088                   ║${NC}"
    echo -e "${GREEN}║ ├ ChineseSubFinder:   http://$(hostname -I | awk '{print $1}'):19035                  ║${NC}"
    echo -e "${GREEN}║ └ FreshRSS:           http://$(hostname -I | awk '{print $1}'):8084                   ║${NC}"
    echo -e "${GREEN}║                                                                             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${YELLOW}📝 重要提示:${NC}"
    echo -e "1. 首次访问各服务需要进行初始配置"
    echo -e "2. 配置文件位置: ${BASE_DIR}/config/.env"
    echo -e "3. 数据目录位置: ${BASE_DIR}"
    echo -e "4. 日志文件位置: $LOG_FILE"
    echo -e "5. 建议先配置 Homepage 导航页，然后依次设置各个服务"
    
    echo -e "\n${CYAN}📖 快速开始${NC}"
    echo -e "1. 访问 Homepage: http://$(hostname -I | awk '{print $1}'):3000"
    echo -e "2. 配置 MoviePilot 自动化规则"
    echo -e "3. 设置 Emby 媒体库扫描路径"
    echo -e "4. 配置下载器和 PT 站点"
    
    echo -e "\n${BLUE}📚 更多文档: 请查看项目 Wiki${NC}"
}

# 创建快捷管理脚本
create_management_scripts() {
    update_progress "创建管理脚本"
    
    # 创建服务管理脚本
    cat > "${BASE_DIR}/scripts/manage-services.sh" << 'EOF'
#!/bin/bash
# NAS 服务管理脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/opt/nas-data"
ENV_FILE="${BASE_DIR}/config/.env"

case "$1" in
    "start")
        echo "启动所有服务.."
        cd "$SCRIPT_DIR/.."
        docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" up -d
        docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" up -d
        ;;
    "stop")
        echo "停止所有服务.."
        cd "$SCRIPT_DIR/.."
        docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" down
        docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" down
        ;;
    "restart")
        echo "重启所有服务.."
        $0 stop
        sleep 5
        $0 start
        ;;
    "status")
        echo "查看服务状态.."
        cd "$SCRIPT_DIR/.."
        docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" ps
        docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" ps
        ;;
    "logs")
        echo "查看服务日志..."
        cd "$SCRIPT_DIR/.."
        docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" logs -f --tail=100 ${2:-}
        ;;
    "update")
        echo "更新所有服务.."
        cd "$SCRIPT_DIR/.."
        docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" pull
        docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" pull
        $0 restart
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs|update} [service_name]"
        echo "示例:"
        echo "  $0 start          # 启动所有服务"
        echo "  $0 stop           # 停止所有服务"  
        echo "  $0 logs moviepilot # 查看 MoviePilot 日志"
        ;;
esac
EOF
    
    chmod +x "${BASE_DIR}/scripts/manage-services.sh"
    
    log "SUCCESS" "管理脚本创建完成: ${BASE_DIR}/scripts/manage-services.sh"
}

# 主安装流程
main() {
    # 显示横幅
    show_banner
    
    # 用户确认
    echo -e "${YELLOW}即将开始安装 NAS 自动化系统，预计耗时 10-30 分钟${NC}"
    read -p "是否继续安装? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "安装已取消"
        exit 0
    fi
    
    # 记录开始时间
    local start_time=$(date +%s)
    log "INFO" "开始安装 NAS 自动化系统.."
    
    # 初始化进度条
    echo "0|初始 > "$PROGRESS_FILE"
    
    # 执行安装步骤
    detect_system
    check_prerequisites
    update_system
    install_docker
    install_docker_compose
    setup_directories
    generate_configs
    pull_docker_images
    start_core_services
    start_extend_services
    create_management_scripts
    
    # 完成进度
    update_progress "安装完成"
    
    # 计算安装时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    # 显示安装结果
    show_install_result
    
    log "SUCCESS" "安装完成！总耗时: ${minutes}分${seconds}秒"
    log "INFO" "重启后服务将自动启动"
    
    # 清理临时文件
    rm -f "$PROGRESS_FILE" "$ROLLBACK_LOG" 2>/dev/null || true
    
    # 询问是否重启
    echo -e "\n${YELLOW}建议重启系统以确保所有服务正常运行${NC}"
    read -p "是否现在重启? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "系统将在 10 秒后重启..."
        sleep 10
        sudo reboot
    fi
}

# 信号处理
trap 'error_exit "安装被中断"' INT TERM

# 执行主函数
main "$@"
