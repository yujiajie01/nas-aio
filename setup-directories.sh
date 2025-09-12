#!/bin/bash

# =============================================================================
# NAS 终极自动化影音管理系统 - 目录结构创建脚本
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 基础目录路径
BASE_DIR="/opt/nas-data"

# 创建基础目录结构
create_directory_structure() {
    log_info "开始创建 NAS 系统目录结构..."
    
    # 创建主要目录
    directories=(
        # 下载目录
        "${BASE_DIR}/downloads/complete"
        "${BASE_DIR}/downloads/incomplete"
        "${BASE_DIR}/downloads/watch"
        "${BASE_DIR}/downloads/torrents"
        
        # 媒体库目录
        "${BASE_DIR}/media/movies"
        "${BASE_DIR}/media/tv"
        "${BASE_DIR}/media/anime"
        "${BASE_DIR}/media/music"
        "${BASE_DIR}/media/audiobooks"
        "${BASE_DIR}/media/comics"
        "${BASE_DIR}/media/books"
        "${BASE_DIR}/media/novels"
        
        # 配置文件目录
        "${BASE_DIR}/config/moviepilot"
        "${BASE_DIR}/config/emby"
        "${BASE_DIR}/config/qbittorrent"
        "${BASE_DIR}/config/transmission"
        "${BASE_DIR}/config/cookiecloud"
        "${BASE_DIR}/config/chinesesubfinder"
        "${BASE_DIR}/config/iyuu"
        "${BASE_DIR}/config/vertex"
        "${BASE_DIR}/config/komga"
        "${BASE_DIR}/config/audiobookshelf"
        "${BASE_DIR}/config/navidrome"
        "${BASE_DIR}/config/calibre"
        "${BASE_DIR}/config/reader"
        "${BASE_DIR}/config/homepage"
        "${BASE_DIR}/config/watchtower"
        "${BASE_DIR}/config/uptimekuma"
        "${BASE_DIR}/config/freshrss"
        "${BASE_DIR}/config/rsshub"
        "${BASE_DIR}/config/metube"
        
        # 脚本目录
        "${BASE_DIR}/scripts/install"
        "${BASE_DIR}/scripts/backup"
        "${BASE_DIR}/scripts/monitoring"
        "${BASE_DIR}/scripts/utils"
        
        # 日志目录
        "${BASE_DIR}/logs/containers"
        "${BASE_DIR}/logs/system"
        "${BASE_DIR}/logs/deployment"
        
        # 缓存目录
        "${BASE_DIR}/cache/temp"
        "${BASE_DIR}/cache/metadata"
        
        # 备份目录
        "${BASE_DIR}/backup/configs"
        "${BASE_DIR}/backup/databases"
        "${BASE_DIR}/backup/scripts"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_success "创建目录: $dir"
        else
            log_warning "目录已存在: $dir"
        fi
    done
}

# 设置目录权限
set_permissions() {
    log_info "设置目录权限..."
    
    # 设置基础权限
    chown -R $(id -u):$(id -g) "${BASE_DIR}"
    chmod -R 755 "${BASE_DIR}"
    
    # 下载目录需要写权限
    chmod -R 777 "${BASE_DIR}/downloads"
    
    # 媒体目录权限
    chmod -R 755 "${BASE_DIR}/media"
    
    # 配置目录权限
    chmod -R 755 "${BASE_DIR}/config"
    
    # 脚本目录可执行权限
    chmod -R 755 "${BASE_DIR}/scripts"
    
    log_success "目录权限设置完成"
}

# 创建示例配置文件
create_sample_configs() {
    log_info "创建示例配置文件..."
    
    # 创建环境变量示例文件
    cat > "${BASE_DIR}/config/.env.example" << 'EOF'
# =============================================================================
# NAS 自动化系统环境变量配置
# =============================================================================

# 基础配置
PUID=1000
PGID=1000
TZ=Asia/Shanghai

# 网络配置
DOMAIN=nas.local
HTTP_PORT=80
HTTPS_PORT=443

# 路径配置
DATA_PATH=/opt/nas-data
DOWNLOAD_PATH=/opt/nas-data/downloads
MEDIA_PATH=/opt/nas-data/media
CONFIG_PATH=/opt/nas-data/config

# MoviePilot 配置
MOVIEPILOT_API_TOKEN=your_api_token_here
MOVIEPILOT_SUPERUSER=admin
MOVIEPILOT_SUPERUSER_PASSWORD=password123

# Emby 配置
EMBY_API_KEY=your_emby_api_key_here

# qBittorrent 配置
QB_WEBUI_PASSWORD=adminpass
QB_USERNAME=admin

# Transmission 配置
TRANSMISSION_USER=admin
TRANSMISSION_PASS=password123

# 微信通知配置
WECHAT_CORP_ID=your_corp_id
WECHAT_CORP_SECRET=your_corp_secret
WECHAT_AGENT_ID=your_agent_id

# PT 站点配置
PT_SITES_CONFIG=your_pt_sites_config
EOF
    
    log_success "示例配置文件创建完成"
}

# 创建README文件
create_readme_files() {
    log_info "创建说明文件..."
    
    # 下载目录说明
    cat > "${BASE_DIR}/downloads/README.md" << 'EOF'
# 下载目录说明

## 目录结构
- `complete/`: 下载完成的文件
- `incomplete/`: 正在下载的文件
- `watch/`: 种子监控目录
- `torrents/`: 种子文件存储

## 注意事项
- 此目录会有大量文件读写操作
- 建议使用SSD或高速存储
- 定期清理临时文件
EOF
    
    # 媒体目录说明
    cat > "${BASE_DIR}/media/README.md" << 'EOF'
# 媒体库目录说明

## 目录结构
- `movies/`: 电影文件
- `tv/`: 电视剧文件
- `anime/`: 动漫文件
- `music/`: 音乐文件
- `audiobooks/`: 有声书文件
- `comics/`: 漫画文件
- `books/`: 电子书文件
- `novels/`: 小说文件

## 文件组织规范
- 电影: movies/电影名称 (年份)/电影文件
- 电视剧: tv/剧名/Season XX/剧集文件
- 音乐: music/艺术家/专辑/音乐文件
EOF
    
    log_success "说明文件创建完成"
}

# 主函数
main() {
    log_info "NAS 自动化系统目录结构初始化开始..."
    
    # 检查是否为root用户
    if [[ $EUID -eq 0 ]]; then
        log_warning "检测到 root 用户执行，将自动设置适当的权限"
    fi
    
    # 检查基础目录是否存在
    if [ -d "$BASE_DIR" ]; then
        log_warning "目录 $BASE_DIR 已存在，将继续创建子目录"
    else
        log_info "创建基础目录: $BASE_DIR"
        mkdir -p "$BASE_DIR"
    fi
    
    # 执行创建步骤
    create_directory_structure
    set_permissions
    create_sample_configs
    create_readme_files
    
    log_success "NAS 系统目录结构初始化完成！"
    log_info "基础目录: $BASE_DIR"
    log_info "请根据需要修改 ${BASE_DIR}/config/.env.example 文件"
    log_info "然后重命名为 .env 开始使用"
}

# 执行主函数
main "$@"