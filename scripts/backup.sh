#!/bin/bash

# =============================================================================
# NAS 自动化系统 - 备份脚本
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
readonly BACKUP_DIR="${BASE_DIR}/backup"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
readonly LOG_FILE="${BACKUP_PATH}/backup.log"

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
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 创建备份目录
create_backup_dir() {
    log "INFO" "创建备份目录: $BACKUP_PATH"
    mkdir -p "$BACKUP_PATH"
    mkdir -p "${BACKUP_PATH}/configs"
    mkdir -p "${BACKUP_PATH}/databases"
    mkdir -p "${BACKUP_PATH}/scripts"
}

# 备份配置文件
backup_configs() {
    log "INFO" "备份配置文件..."
    
    # 备份主配置目录
    if [ -d "${BASE_DIR}/config" ]; then
        tar -czf "${BACKUP_PATH}/configs/config.tar.gz" -C "${BASE_DIR}" config
        log "SUCCESS" "配置文件备份完成"
    else
        log "WARNING" "配置目录不存在，跳过备份"
    fi
    
    # 备份 Docker Compose 文件
    cp docker-compose.*.yml "${BACKUP_PATH}/configs/" 2>/dev/null || true
    cp .env "${BACKUP_PATH}/configs/" 2>/dev/null || true
}

# 备份数据库
backup_databases() {
    log "INFO" "备份数据库..."
    
    # MoviePilot 数据库
    if docker ps | grep -q moviepilot; then
        docker exec moviepilot sqlite3 /config/user.db ".backup '/tmp/moviepilot_backup.db'"
        docker cp moviepilot:/tmp/moviepilot_backup.db "${BACKUP_PATH}/databases/"
        log "SUCCESS" "MoviePilot 数据库备份完成"
    fi
    
    # Emby 数据库
    if [ -d "${BASE_DIR}/config/emby/data" ]; then
        tar -czf "${BACKUP_PATH}/databases/emby_data.tar.gz" -C "${BASE_DIR}/config/emby" data
        log "SUCCESS" "Emby 数据库备份完成"
    fi
    
    # 其他服务数据库备份...
}

# 备份脚本
backup_scripts() {
    log "INFO" "备份脚本文件..."
    
    if [ -d "${BASE_DIR}/scripts" ]; then
        cp -r "${BASE_DIR}/scripts" "${BACKUP_PATH}/"
        log "SUCCESS" "脚本文件备份完成"
    fi
}

# 创建系统信息快照
create_system_snapshot() {
    log "INFO" "创建系统信息快照..."
    
    {
        echo "=== 系统信息 ==="
        uname -a
        echo
        echo "=== Docker 版本 ==="
        docker --version
        docker-compose --version
        echo
        echo "=== 运行中的容器 ==="
        docker ps
        echo
        echo "=== 容器镜像 ==="
        docker images
        echo
        echo "=== 磁盘使用情况 ==="
        df -h
        echo
        echo "=== 内存使用情况 ==="
        free -h
        echo
        echo "=== 网络配置 ==="
        ip addr show
    } > "${BACKUP_PATH}/system_info.txt"
    
    log "SUCCESS" "系统信息快照创建完成"
}

# 压缩备份
compress_backup() {
    log "INFO" "压缩备份文件..."
    
    cd "$BACKUP_DIR"
    tar -czf "${TIMESTAMP}_full_backup.tar.gz" "$TIMESTAMP"
    
    # 计算备份大小
    local backup_size=$(du -h "${TIMESTAMP}_full_backup.tar.gz" | cut -f1)
    log "SUCCESS" "备份压缩完成，大小: $backup_size"
    
    # 删除未压缩的目录
    rm -rf "$TIMESTAMP"
}

# 清理旧备份
cleanup_old_backups() {
    log "INFO" "清理旧备份文件..."
    
    # 保留最近7天的备份
    find "$BACKUP_DIR" -name "*_full_backup.tar.gz" -mtime +7 -delete
    
    # 统计剩余备份数量
    local backup_count=$(find "$BACKUP_DIR" -name "*_full_backup.tar.gz" | wc -l)
    log "SUCCESS" "旧备份清理完成，当前保留 $backup_count 个备份文件"
}

# 发送通知
send_notification() {
    local status="$1"
    local message="$2"
    
    # 这里可以集成微信通知、邮件通知等
    log "INFO" "备份通知: $message"
}

# 主备份流程
main() {
    log "INFO" "开始系统备份..."
    local start_time=$(date +%s)
    
    # 检查备份目录
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    
    # 执行备份步骤
    create_backup_dir
    backup_configs
    backup_databases
    backup_scripts
    create_system_snapshot
    compress_backup
    cleanup_old_backups
    
    # 计算备份时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    log "SUCCESS" "系统备份完成！"
    log "INFO" "备份文件: ${BACKUP_DIR}/${TIMESTAMP}_full_backup.tar.gz"
    log "INFO" "备份耗时: ${minutes}分${seconds}秒"
    
    send_notification "success" "NAS系统备份成功完成"
}

# 错误处理
error_exit() {
    log "ERROR" "$1"
    send_notification "error" "NAS系统备份失败: $1"
    exit 1
}

# 信号处理
trap 'error_exit "备份被中断"' INT TERM

# 使用说明
show_usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -c, --config   仅备份配置文件"
    echo "  -d, --database 仅备份数据库"
    echo "  -s, --scripts  仅备份脚本文件"
    echo "  -f, --full     完整备份（默认）"
}

# 参数解析
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    -c|--config)
        log "INFO" "仅备份配置文件"
        create_backup_dir
        backup_configs
        compress_backup
        ;;
    -d|--database)
        log "INFO" "仅备份数据库"
        create_backup_dir
        backup_databases
        compress_backup
        ;;
    -s|--scripts)
        log "INFO" "仅备份脚本文件"
        create_backup_dir
        backup_scripts
        compress_backup
        ;;
    -f|--full|"")
        main
        ;;
    *)
        echo "未知选项: $1"
        show_usage
        exit 1
        ;;
esac