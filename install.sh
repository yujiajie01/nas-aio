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
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 错误处理
error_exit() {
    log "ERROR" "$1"
    log "ERROR" "安装失败，请检查日志文件: $LOG_FILE"
    exit 1
}

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║            NAS 终极自动化影音管理系统 - 一键安装脚本                         ║
║                                                                              ║
║  ┌─────────────────────────────────────────────────────────────────────────┐ ║
║  │  🎯 核心特性                                                            │ ║
║  │  • 全自动化流水线: 搜索 → 下载 → 整理 → 通知                           │ ║
║  │  • 一站式数字生活中心: 影视、音乐、漫画、电子书                         │ ║
║  │  • PT 生态深度集成: 自动辅种、刷流、Cookie 同步                        │ ║
║  │  • 极致用户体验: 统一导航页 + 微信通知 + 多设备访问                     │ ║
║  └─────────────────────────────────────────────────────────────────────────┘ ║
║                                                                              ║
║  版本: v1.0.0                                                               ║
║  支持: Ubuntu 20.04+, Debian 11+, CentOS 8+                                ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检测系统信息
detect_system() {
    log "INFO" "检测系统信息..."
    
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
    log "INFO" "检查前置条件..."
    
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
    log "INFO" "更新系统包..."
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            sudo apt update && sudo apt upgrade -y
            sudo apt install -y curl wget git unzip htop iotop nethogs tree vim nano
            ;;
        *"CentOS"*|*"Red Hat"*)
            sudo yum update -y
            sudo yum install -y curl wget git unzip htop iotop nethogs tree vim nano
            ;;
        *)
            log "WARNING" "未知系统类型，跳过系统更新"
            ;;
    esac
    
    log "SUCCESS" "系统更新完成"
}

# 安装 Docker
install_docker() {
    log "INFO" "安装 Docker..."
    
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
    
    log "SUCCESS" "Docker Compose 安装完成"
}

# 创建目录结构
setup_directories() {
    log "INFO" "创建目录结构..."
    
    if [ -x "${SCRIPT_DIR}/setup-directories.sh" ]; then
        bash "${SCRIPT_DIR}/setup-directories.sh"
    else
        error_exit "找不到目录设置脚本: ${SCRIPT_DIR}/setup-directories.sh"
    fi
    
    log "SUCCESS" "目录结构创建完成"
}

# 生成配置文件
generate_configs() {
    log "INFO" "生成配置文件..."
    
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
        
        log "SUCCESS" "配置文件生成完成"
        log "INFO" "配置文件位置: ${BASE_DIR}/config/.env"
        log "INFO" "请根据需要修改配置参数"
    else
        error_exit "找不到配置文件模板"
    fi
}

# 拉取 Docker 镜像
pull_docker_images() {
    log "INFO" "拉取 Docker 镜像（这可能需要较长时间）..."
    
    cd "$SCRIPT_DIR"
    
    # 设置环境变量文件路径
    export ENV_FILE="${BASE_DIR}/config/.env"
    
    # 拉取核心服务镜像
    docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" pull
    
    # 拉取扩展服务镜像
    docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" pull
    
    log "SUCCESS" "Docker 镜像拉取完成"
}

# 启动核心服务
start_core_services() {
    log "INFO" "启动核心服务..."
    
    cd "$SCRIPT_DIR"
    export ENV_FILE="${BASE_DIR}/config/.env"
    
    # 启动核心服务
    docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" up -d
    
    # 等待服务启动
    log "INFO" "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    check_service_status "core"
    
    log "SUCCESS" "核心服务启动完成"
}

# 启动扩展服务
start_extend_services() {
    log "INFO" "启动扩展服务..."
    
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
    log "INFO" "检查 $service_type 服务状态..."
    
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
    echo -e "${GREEN}║                           安装完成 - 服务访问地址                           ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}║  📊 核心服务                                                                ║${NC}"
    echo -e "${GREEN}║  • Homepage 导航页:    http://$(hostname -I | awk '{print $1}'):3000                   ║${NC}"
    echo -e "${GREEN}║  • MoviePilot 调度:    http://$(hostname -I | awk '{print $1}'):8001                   ║${NC}"
    echo -e "${GREEN}║  • Emby 媒体服务器:    http://$(hostname -I | awk '{print $1}'):8096                   ║${NC}"
    echo -e "${GREEN}║  • qBittorrent 下载:   http://$(hostname -I | awk '{print $1}'):8080                   ║${NC}"
    echo -e "${GREEN}║  • Transmission 保种:  http://$(hostname -I | awk '{print $1}'):9091                   ║${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}║  📚 媒体库服务                                                              ║${NC}"
    echo -e "${GREEN}║  • Komga 漫画库:       http://$(hostname -I | awk '{print $1}'):25600                  ║${NC}"
    echo -e "${GREEN}║  • Audiobookshelf:     http://$(hostname -I | awk '{print $1}'):25378                  ║${NC}"
    echo -e "${GREEN}║  • Navidrome 音乐:     http://$(hostname -I | awk '{print $1}'):25533                  ║${NC}"
    echo -e "${GREEN}║  • Calibre 电子书:     http://$(hostname -I | awk '{print $1}'):8083                   ║${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}║  🔧 工具服务                                                                ║${NC}"
    echo -e "${GREEN}║  • CookieCloud:        http://$(hostname -I | awk '{print $1}'):8088                   ║${NC}"
    echo -e "${GREEN}║  • ChineseSubFinder:   http://$(hostname -I | awk '{print $1}'):19035                  ║${NC}"
    echo -e "${GREEN}║  • FreshRSS:           http://$(hostname -I | awk '{print $1}'):8084                   ║${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${YELLOW}📝 重要提示:${NC}"
    echo -e "1. 首次访问各服务需要进行初始配置"
    echo -e "2. 配置文件位置: ${BASE_DIR}/config/.env"
    echo -e "3. 数据目录位置: ${BASE_DIR}"
    echo -e "4. 日志文件位置: $LOG_FILE"
    echo -e "5. 建议先配置 Homepage 导航页，然后依次设置各个服务"
    
    echo -e "\n${CYAN}📖 快速开始:${NC}"
    echo -e "1. 访问 Homepage: http://$(hostname -I | awk '{print $1}'):3000"
    echo -e "2. 配置 MoviePilot 自动化规则"
    echo -e "3. 设置 Emby 媒体库扫描路径"
    echo -e "4. 配置下载器和 PT 站点"
    
    echo -e "\n${BLUE}📚 更多文档: 请查看项目 Wiki${NC}"
}

# 创建快捷管理脚本
create_management_scripts() {
    log "INFO" "创建管理脚本..."
    
    # 创建服务管理脚本
    cat > "${BASE_DIR}/scripts/manage-services.sh" << 'EOF'
#!/bin/bash
# NAS 服务管理脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/opt/nas-data"
ENV_FILE="${BASE_DIR}/config/.env"

case "$1" in
    "start")
        echo "启动所有服务..."
        cd "$SCRIPT_DIR/.."
        docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" up -d
        docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" up -d
        ;;
    "stop")
        echo "停止所有服务..."
        cd "$SCRIPT_DIR/.."
        docker-compose -f docker-compose.core.yml --env-file "$ENV_FILE" down
        docker-compose -f docker-compose.extend.yml --env-file "$ENV_FILE" down
        ;;
    "restart")
        echo "重启所有服务..."
        $0 stop
        sleep 5
        $0 start
        ;;
    "status")
        echo "查看服务状态..."
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
        echo "更新所有服务..."
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
    log "INFO" "开始安装 NAS 自动化系统..."
    
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
    
    # 计算安装时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    # 显示安装结果
    show_install_result
    
    log "SUCCESS" "安装完成！总耗时: ${minutes}分${seconds}秒"
    log "INFO" "重启后服务将自动启动"
    
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