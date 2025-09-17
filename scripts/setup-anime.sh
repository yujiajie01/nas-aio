#!/bin/bash

# =============================================================================
# 自动追番系统初始化脚本
# =============================================================================

set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 配置变量
readonly BASE_DIR="/opt/nas-data"
readonly ANIME_DIR="${BASE_DIR}/anime"
readonly CONFIG_PATH="${BASE_DIR}/config"
readonly DOWNLOAD_PATH="${BASE_DIR}/downloads"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# 显示横幅
show_banner() {
    clear
    echo -e "${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    最简自动追番系统 - 初始化脚本                            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  功能特性:                                                                   ║
║  • 支持多站点 RSS 订阅 (Mikan Project, 动漫花园, 萌番组)                    ║
║  • 自动下载新番剧集                                                         ║
║  • 智能文件分类管理                                                         ║
║  • 磁盘空间自动管理                                                         ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检查系统要求
check_requirements() {
    log "INFO" "检查系统要求..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log "ERROR" "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "ERROR" "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    log "SUCCESS" "系统要求检查通过"
}

# 创建目录结构
setup_directories() {
    log "INFO" "创建目录结构..."
    
    # 创建基础目录
    sudo mkdir -p "${BASE_DIR}"
    sudo mkdir -p "${CONFIG_PATH}"
    sudo mkdir -p "${DOWNLOAD_PATH}"
    sudo mkdir -p "${ANIME_DIR}"
    
    # 创建动漫相关目录
    sudo mkdir -p "${CONFIG_PATH}/anime-qbittorrent"
    sudo mkdir -p "${CONFIG_PATH}/anime-flexget"
    sudo mkdir -p "${DOWNLOAD_PATH}/anime"
    sudo mkdir -p "${DOWNLOAD_PATH}/anime/mikan"
    sudo mkdir -p "${DOWNLOAD_PATH}/anime/dmhy"
    sudo mkdir -p "${DOWNLOAD_PATH}/anime/bangumi-moe"
    sudo mkdir -p "${ANIME_DIR}/complete"
    
    # 设置权限
    sudo chown -R $(id -u):$(id -g) "${BASE_DIR}"
    sudo chmod -R 755 "${BASE_DIR}"
    sudo chmod -R 777 "${DOWNLOAD_PATH}"
    
    log "SUCCESS" "目录结构创建完成"
}

# 配置环境变量
setup_env() {
    log "INFO" "配置环境变量..."
    
    # 创建 .env 文件
    cat > "${SCRIPT_DIR}/.env" << EOF
# 自动追番系统环境变量配置

# 基础配置
PUID=$(id -u)
PGID=$(id -g)
TZ=Asia/Shanghai

# 路径配置
BASE_DIR=${BASE_DIR}
CONFIG_PATH=${CONFIG_PATH}
DOWNLOAD_PATH=${DOWNLOAD_PATH}
ANIME_DIR=${ANIME_DIR}

# FlexGet 配置
FLEXGET_WEBUI_PASS=password123
EOF
    
    log "SUCCESS" "环境变量配置完成"
}

# 配置 FlexGet
setup_flexget() {
    log "INFO" "配置 FlexGet..."
    
    # 复制配置文件
    if [ -f "${SCRIPT_DIR}/config/anime-flexget/config.yml" ]; then
        cp "${SCRIPT_DIR}/config/anime-flexget/config.yml" "${CONFIG_PATH}/anime-flexget/config.yml"
        log "SUCCESS" "FlexGet 配置文件复制完成"
    else
        log "WARNING" "FlexGet 配置文件不存在，将使用默认配置"
    fi
}

# 启动服务
start_services() {
    log "INFO" "启动自动追番服务..."
    
    # 进入脚本目录
    cd "${SCRIPT_DIR}"
    
    # 启动服务
    docker-compose -f docker-compose.anime-minimal.yml --env-file .env up -d
    
    # 等待服务启动
    log "INFO" "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    docker-compose -f docker-compose.anime-minimal.yml --env-file .env ps
    
    log "SUCCESS" "自动追番服务启动完成"
}

# 显示使用说明
show_usage() {
    echo
    echo -e "${YELLOW}=== 使用说明 ===${NC}"
    echo
    echo -e "${GREEN}1. 访问 qBittorrent:${NC}"
    echo "   地址: http://localhost:8080"
    echo "   用户名: admin"
    echo "   密码: adminadmin"
    echo
    echo -e "${GREEN}2. 访问 FlexGet Web UI:${NC}"
    echo "   地址: http://localhost:5050"
    echo "   用户名: flexget"
    echo "   密码: password123"
    echo
    echo -e "${GREEN}3. 配置 RSS 订阅:${NC}"
    echo "   编辑配置文件: ${CONFIG_PATH}/anime-flexget/config.yml"
    echo "   修改 RSS 地址和订阅关键词"
    echo
    echo -e "${GREEN}4. 管理命令:${NC}"
    echo "   启动服务: docker-compose -f docker-compose.anime-minimal.yml up -d"
    echo "   停止服务: docker-compose -f docker-compose.anime-minimal.yml down"
    echo "   查看日志: docker-compose -f docker-compose.anime-minimal.yml logs -f"
    echo
    echo -e "${GREEN}5. 文件位置:${NC}"
    echo "   下载目录: ${DOWNLOAD_PATH}/anime"
    echo "   完成目录: ${ANIME_DIR}/complete"
    echo
}

# 主函数
main() {
    show_banner
    
    log "INFO" "开始初始化自动追番系统..."
    
    check_requirements
    setup_directories
    setup_env
    setup_flexget
    start_services
    
    log "SUCCESS" "自动追番系统初始化完成！"
    
    show_usage
}

# 执行主函数
main "$@"