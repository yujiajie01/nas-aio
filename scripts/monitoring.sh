#!/bin/bash

# =============================================================================
# NAS 自动化系统 - 系统监控脚本
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
readonly LOG_FILE="${BASE_DIR}/logs/monitoring.log"
readonly ALERT_FILE="${BASE_DIR}/logs/alerts.log"

# 告警阈值
readonly CPU_THRESHOLD=80
readonly MEMORY_THRESHOLD=85
readonly DISK_THRESHOLD=90
readonly CONTAINER_DOWN_TIME=300  # 5分钟

# 初始化
init_monitoring() {
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$ALERT_FILE")"
}

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
        "ALERT")
            echo -e "${RED}[ALERT]${NC} $message"
            echo "[$timestamp] [ALERT] $message" >> "$ALERT_FILE"
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 检查系统资源
check_system_resources() {
    log "INFO" "检查系统资源使用情况..."
    
    # CPU 使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    cpu_usage=${cpu_usage%.*}  # 去除小数部分
    
    if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
        log "ALERT" "CPU 使用率过高: ${cpu_usage}% (阈值: ${CPU_THRESHOLD}%)"
    else
        log "INFO" "CPU 使用率正常: ${cpu_usage}%"
    fi
    
    # 内存使用率
    local memory_info=$(free | grep Mem)
    local total_memory=$(echo $memory_info | awk '{print $2}')
    local used_memory=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$((used_memory * 100 / total_memory))
    
    if [ "$memory_usage" -gt "$MEMORY_THRESHOLD" ]; then
        log "ALERT" "内存使用率过高: ${memory_usage}% (阈值: ${MEMORY_THRESHOLD}%)"
    else
        log "INFO" "内存使用率正常: ${memory_usage}%"
    fi
    
    # 磁盘使用率
    while IFS= read -r line; do
        local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        local mount_point=$(echo "$line" | awk '{print $6}')
        
        if [ "$usage" -gt "$DISK_THRESHOLD" ]; then
            log "ALERT" "磁盘空间不足: ${mount_point} ${usage}% (阈值: ${DISK_THRESHOLD}%)"
        else
            log "INFO" "磁盘使用率正常: ${mount_point} ${usage}%"
        fi
    done < <(df -h | grep -E '^/dev/' | grep -v tmpfs)
}

# 检查 Docker 服务状态
check_docker_status() {
    log "INFO" "检查 Docker 服务状态..."
    
    if ! systemctl is-active --quiet docker; then
        log "ALERT" "Docker 服务未运行"
        return 1
    fi
    
    log "SUCCESS" "Docker 服务运行正常"
}

# 检查容器状态
check_container_status() {
    log "INFO" "检查容器状态..."
    
    # 定义重要容器列表
    local important_containers=(
        "moviepilot"
        "emby" 
        "qbittorrent"
        "transmission"
        "homepage"
    )
    
    for container in "${important_containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
            log "SUCCESS" "容器 ${container} 运行正常"
        else
            log "ALERT" "重要容器 ${container} 未运行"
            
            # 尝试重启容器
            log "INFO" "尝试重启容器 ${container}..."
            if docker start "$container" &>/dev/null; then
                log "SUCCESS" "容器 ${container} 重启成功"
            else
                log "ERROR" "容器 ${container} 重启失败"
            fi
        fi
    done
}

# 检查网络连通性
check_network_connectivity() {
    log "INFO" "检查网络连通性..."
    
    # 检查外网连接
    if ping -c 1 8.8.8.8 &>/dev/null; then
        log "SUCCESS" "外网连接正常"
    else
        log "ALERT" "外网连接异常"
    fi
    
    # 检查关键服务端口
    local services=(
        "3000:Homepage"
        "8001:MoviePilot"
        "8096:Emby"
        "8080:qBittorrent"
        "9091:Transmission"
    )
    
    for service in "${services[@]}"; do
        local port="${service%%:*}"
        local name="${service##*:}"
        
        if netstat -tuln | grep -q ":${port} "; then
            log "SUCCESS" "${name} 端口 ${port} 监听正常"
        else
            log "WARNING" "${name} 端口 ${port} 未监听"
        fi
    done
}

# 检查下载器状态
check_downloader_status() {
    log "INFO" "检查下载器状态..."
    
    # 检查 qBittorrent API
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/api/v2/app/version" | grep -q "200"; then
        log "SUCCESS" "qBittorrent API 响应正常"
        
        # 获取下载统计
        local active_downloads=$(curl -s "http://localhost:8080/api/v2/torrents/info?filter=downloading" | jq length 2>/dev/null || echo "0")
        log "INFO" "当前活跃下载任务: ${active_downloads}"
    else
        log "ALERT" "qBittorrent API 无响应"
    fi
    
    # 检查 Transmission API
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:9091/transmission/web/" | grep -q "200\|401"; then
        log "SUCCESS" "Transmission Web 界面正常"
    else
        log "ALERT" "Transmission Web 界面无响应"
    fi
}

# 检查媒体库状态
check_media_library() {
    log "INFO" "检查媒体库状态..."
    
    # 检查 Emby API
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8096/health" | grep -q "200"; then
        log "SUCCESS" "Emby 服务响应正常"
    else
        log "ALERT" "Emby 服务无响应"
    fi
    
    # 检查媒体目录
    local media_dirs=(
        "${BASE_DIR}/media/movies"
        "${BASE_DIR}/media/tv"
        "${BASE_DIR}/media/music"
    )
    
    for dir in "${media_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local file_count=$(find "$dir" -type f | wc -l)
            log "INFO" "媒体目录 $(basename "$dir"): ${file_count} 个文件"
        else
            log "WARNING" "媒体目录不存在: $dir"
        fi
    done
}

# 检查存储空间趋势
check_storage_trend() {
    log "INFO" "检查存储空间趋势..."
    
    local downloads_size=$(du -sh "${BASE_DIR}/downloads" 2>/dev/null | cut -f1 || echo "0")
    local media_size=$(du -sh "${BASE_DIR}/media" 2>/dev/null | cut -f1 || echo "0")
    
    log "INFO" "下载目录大小: ${downloads_size}"
    log "INFO" "媒体库大小: ${media_size}"
    
    # 检查下载目录是否过大
    local downloads_gb=$(du -s "${BASE_DIR}/downloads" 2>/dev/null | awk '{print int($1/1024/1024)}')
    if [ "$downloads_gb" -gt 100 ]; then
        log "WARNING" "下载目录占用空间较大: ${downloads_gb}GB，建议清理完成的下载"
    fi
}

# 生成监控报告
generate_report() {
    local report_file="${BASE_DIR}/logs/monitoring_report_$(date +%Y%m%d_%H%M).txt"
    
    {
        echo "=== NAS 系统监控报告 ==="
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        echo "=== 系统信息 ==="
        echo "系统负载: $(uptime)"
        echo "运行时间: $(uptime -p)"
        echo
        echo "=== 容器状态 ==="
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo
        echo "=== 存储使用情况 ==="
        df -h
        echo
        echo "=== 近期告警 ==="
        tail -n 20 "$ALERT_FILE" 2>/dev/null || echo "无告警记录"
    } > "$report_file"
    
    log "SUCCESS" "监控报告已生成: $report_file"
}

# 发送告警通知
send_alert() {
    local message="$1"
    
    # 微信通知（需要配置）
    # curl -s -X POST "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY" \
    #      -H 'Content-Type: application/json' \
    #      -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"$message\"}}"
    
    # 邮件通知（需要配置）
    # echo "$message" | mail -s "NAS系统告警" admin@example.com
    
    log "INFO" "告警通知: $message"
}

# 自动修复功能
auto_repair() {
    log "INFO" "执行自动修复..."
    
    # 清理 Docker 无用数据
    docker system prune -f --volumes
    
    # 重启异常容器
    local failed_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}")
    if [ -n "$failed_containers" ]; then
        echo "$failed_containers" | while read -r container; do
            log "INFO" "重启异常容器: $container"
            docker restart "$container"
        done
    fi
    
    # 清理下载临时文件
    find "${BASE_DIR}/downloads/incomplete" -name "*.!qB" -mtime +7 -delete 2>/dev/null || true
    
    log "SUCCESS" "自动修复完成"
}

# 主监控流程
main() {
    init_monitoring
    log "INFO" "开始系统监控检查..."
    
    check_system_resources
    check_docker_status
    check_container_status
    check_network_connectivity
    check_downloader_status
    check_media_library
    check_storage_trend
    
    # 检查是否需要自动修复
    if [ "${1:-}" = "--auto-repair" ]; then
        auto_repair
    fi
    
    # 生成报告
    if [ "${1:-}" = "--report" ]; then
        generate_report
    fi
    
    log "SUCCESS" "监控检查完成"
}

# 使用说明
show_usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help        显示帮助信息"
    echo "  --auto-repair     执行自动修复"
    echo "  --report          生成监控报告"
    echo "  --daemon          守护进程模式"
}

# 守护进程模式
daemon_mode() {
    log "INFO" "启动守护进程监控模式..."
    
    while true; do
        main
        log "INFO" "等待下次检查..."
        sleep 300  # 5分钟检查一次
    done
}

# 参数解析
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    --daemon)
        daemon_mode
        ;;
    *)
        main "$@"
        ;;
esac