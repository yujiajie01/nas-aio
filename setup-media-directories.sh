#!/bin/bash

# =============================================================================
# 自动化追剧系统 - 媒体目录结构创建脚本
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
MEDIA_BASE_DIR="/opt/nas-data/media"
DOCKER_BASE_DIR="/opt/nas-data/config"

# 创建媒体目录结构
create_media_directories() {
    log_info "开始创建自动化追剧系统媒体目录结构..."
    
    # 创建主要媒体目录
    media_directories=(
        # 媒体库目录
        "${MEDIA_BASE_DIR}/Movies"
        "${MEDIA_BASE_DIR}/TV-Shows"
        "${MEDIA_BASE_DIR}/Downloads"
        
        # 下载子目录
        "${MEDIA_BASE_DIR}/Downloads/qbittorrent"
        "${MEDIA_BASE_DIR}/Downloads/radarr"
        "${MEDIA_BASE_DIR}/Downloads/sonarr"
        
        # 电影和电视剧最终目录
        "${MEDIA_BASE_DIR}/Movies"
        "${MEDIA_BASE_DIR}/TV-Shows"
    )
    
    for dir in "${media_directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_success "创建目录: $dir"
        else
            log_warning "目录已存在: $dir"
        fi
    done
}

# 创建Docker配置目录
create_docker_directories() {
    log_info "创建Docker配置目录..."
    
    # 创建配置目录
    config_directories=(
        "${DOCKER_BASE_DIR}/radarr"
        "${DOCKER_BASE_DIR}/sonarr"
        "${DOCKER_BASE_DIR}/prowlarr"
        "${DOCKER_BASE_DIR}/qbittorrent"
    )
    
    for dir in "${config_directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_success "创建配置目录: $dir"
        else
            log_warning "配置目录已存在: $dir"
        fi
    done
}

# 设置目录权限
set_permissions() {
    log_info "设置目录权限..."
    
    # 设置基础权限
    chown -R $(id -u):$(id -g) "${MEDIA_BASE_DIR}"
    chmod -R 755 "${MEDIA_BASE_DIR}"
    
    # 下载目录需要写权限
    chmod -R 777 "${MEDIA_BASE_DIR}/Downloads"
    
    # 配置目录权限
    chmod -R 755 "${DOCKER_BASE_DIR}"
    
    log_success "目录权限设置完成"
}

# 创建说明文件
create_readme_files() {
    log_info "创建说明文件..."
    
    # 媒体目录说明
    cat > "${MEDIA_BASE_DIR}/README.md" << 'EOF'
# 自动化追剧系统媒体目录说明

## 目录结构
- `Movies/`: Radarr整理后的电影最终目录
- `TV-Shows/`: Sonarr整理后的电视剧最终目录
- `Downloads/`: 下载中的文件和处理种子

## 文件组织规范
- 电影: Movies/电影名称 (年份)/电影文件
- 电视剧: TV-Shows/剧名/Season XX/剧集文件

## 注意事项
- 此目录结构专为Radarr/Sonarr自动化追剧系统设计
- 请勿手动修改目录结构，以免影响自动化流程
EOF
    
    log_success "说明文件创建完成"
}

# 主函数
main() {
    log_info "自动化追剧系统目录结构初始化开始..."
    
    # 检查是否为root用户
    if [[ $EUID -eq 0 ]]; then
        log_warning "检测到 root 用户执行，将自动设置适当的权限"
    fi
    
    # 检查基础目录是否存在
    if [ ! -d "/opt/nas-data" ]; then
        log_info "创建基础目录: /opt/nas-data"
        mkdir -p /opt/nas-data
    fi
    
    # 执行创建步骤
    create_media_directories
    create_docker_directories
    set_permissions
    create_readme_files
    
    log_success "自动化追剧系统目录结构初始化完成！"
    log_info "媒体目录: $MEDIA_BASE_DIR"
    log_info "配置目录: $DOCKER_BASE_DIR"
}

# 执行主函数
main "$@"