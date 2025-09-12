#!/bin/bash

# =============================================================================
# NAS 自动化系统 - 系统集成测试脚本
# =============================================================================

set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 全局变量
readonly BASE_DIR="/opt/nas-data"
readonly TEST_LOG="/tmp/nas-system-test.log"
readonly HOST_IP=$(hostname -I | awk '{print $1}')

# 测试结果统计
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$TEST_LOG"
            ;;
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $message" | tee -a "$TEST_LOG"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message" | tee -a "$TEST_LOG"
            ((TESTS_FAILED++))
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$TEST_LOG"
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$TEST_LOG"
    ((TESTS_TOTAL++))
}

# 测试函数
test_case() {
    local test_name="$1"
    local test_command="$2"
    
    log "INFO" "执行测试: $test_name"
    
    if eval "$test_command" &>/dev/null; then
        log "PASS" "$test_name"
        return 0
    else
        log "FAIL" "$test_name"
        return 1
    fi
}

# 显示测试开始横幅
show_test_banner() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                       NAS 自动化系统 - 系统集成测试                         ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    log "INFO" "开始系统集成测试..."
    log "INFO" "服务器IP: $HOST_IP"
    log "INFO" "测试时间: $(date)"
}

# 1. 基础环境测试
test_basic_environment() {
    log "INFO" "=== 基础环境测试 ==="
    
    # 测试 Docker 服务
    test_case "Docker 服务运行状态" "systemctl is-active --quiet docker"
    
    # 测试 Docker Compose
    test_case "Docker Compose 可用性" "docker-compose --version"
    
    # 测试数据目录
    test_case "数据目录存在" "[ -d '$BASE_DIR' ]"
    
    # 测试目录权限
    test_case "数据目录可写" "[ -w '$BASE_DIR' ]"
    
    # 测试磁盘空间
    local disk_usage=$(df "$BASE_DIR" | awk 'NR==2 {print $(NF-1)}' | sed 's/%//')
    test_case "磁盘空间充足 (<90%)" "[ $disk_usage -lt 90 ]"
}

# 2. 网络连接测试
test_network_connectivity() {
    log "INFO" "=== 网络连接测试 ==="
    
    # 测试外网连接
    test_case "外网连接" "ping -c 1 8.8.8.8"
    
    # 测试 Docker 网络
    test_case "Docker 网络存在" "docker network ls | grep -q nas-network"
    
    # 测试端口监听
    local ports=(3000 8001 8096 8080 9091)
    for port in "${ports[@]}"; do
        test_case "端口 $port 监听" "netstat -tuln | grep -q ':$port '"
    done
}

# 3. 容器服务测试
test_container_services() {
    log "INFO" "=== 容器服务测试 ==="
    
    # 核心容器运行状态
    local core_containers=("moviepilot" "emby" "qbittorrent" "transmission" "homepage")
    for container in "${core_containers[@]}"; do
        test_case "容器 $container 运行中" "docker ps | grep -q $container"
    done
    
    # 容器健康检查
    for container in "${core_containers[@]}"; do
        if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
            local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
            if [ "$health_status" = "healthy" ] || [ "$health_status" = "none" ]; then
                log "PASS" "容器 $container 健康检查"
            else
                log "FAIL" "容器 $container 健康检查失败: $health_status"
            fi
        fi
    done
}

# 4. Web 服务访问测试
test_web_services() {
    log "INFO" "=== Web 服务访问测试 ==="
    
    # HTTP 状态码测试
    local services=(
        "Homepage:3000"
        "MoviePilot:8001"
        "Emby:8096"
        "qBittorrent:8080"
        "Transmission:9091"
    )
    
    for service_info in "${services[@]}"; do
        local service_name="${service_info%%:*}"
        local port="${service_info##*:}"
        local url="http://localhost:$port"
        
        local http_code=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 10 "$url" 2>/dev/null || echo "000")
        
        if [[ "$http_code" =~ ^[23] ]]; then
            log "PASS" "$service_name Web 服务访问 (HTTP $http_code)"
        else
            log "FAIL" "$service_name Web 服务访问失败 (HTTP $http_code)"
        fi
    done
}

# 5. API 接口测试
test_api_interfaces() {
    log "INFO" "=== API 接口测试 ==="
    
    # MoviePilot API 测试
    local mp_api_response=$(curl -s --connect-timeout 10 "http://localhost:8001/api/v1/system/status" 2>/dev/null || echo "")
    test_case "MoviePilot API 响应" "[ -n '$mp_api_response' ]"
    
    # Emby API 测试
    local emby_health=$(curl -s --connect-timeout 10 "http://localhost:8096/health" 2>/dev/null || echo "")
    test_case "Emby Health API 响应" "[ -n '$emby_health' ]"
    
    # qBittorrent API 测试
    local qb_version=$(curl -s --connect-timeout 10 "http://localhost:8080/api/v2/app/version" 2>/dev/null || echo "")
    test_case "qBittorrent API 响应" "[ -n '$qb_version' ]"
}

# 6. 数据存储测试
test_data_storage() {
    log "INFO" "=== 数据存储测试 ==="
    
    # 测试目录结构
    local directories=(
        "$BASE_DIR/downloads"
        "$BASE_DIR/media"
        "$BASE_DIR/config"
        "$BASE_DIR/logs"
    )
    
    for dir in "${directories[@]}"; do
        test_case "目录 $dir 存在" "[ -d '$dir' ]"
    done
    
    # 测试文件创建权限
    local test_file="$BASE_DIR/test_write_permission.tmp"
    test_case "文件写入权限" "touch '$test_file' && rm -f '$test_file'"
    
    # 测试配置文件
    test_case "环境配置文件存在" "[ -f '$BASE_DIR/config/.env' ] || [ -f '.env' ]"
}

# 7. 服务联动测试
test_service_integration() {
    log "INFO" "=== 服务联动测试 ==="
    
    # 测试容器间网络通信
    if docker ps | grep -q moviepilot; then
        test_case "MoviePilot → qBittorrent 通信" "docker exec moviepilot ping -c 1 qbittorrent"
        test_case "MoviePilot → Emby 通信" "docker exec moviepilot ping -c 1 emby"
    fi
    
    # 测试共享存储访问
    if docker ps | grep -q emby; then
        test_case "Emby 访问媒体目录" "docker exec emby ls /media"
    fi
    
    if docker ps | grep -q qbittorrent; then
        test_case "qBittorrent 访问下载目录" "docker exec qbittorrent ls /downloads"
    fi
}

# 8. 性能基准测试
test_performance_baseline() {
    log "INFO" "=== 性能基准测试 ==="
    
    # CPU 使用率测试
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}' | cut -d'u' -f1)
    cpu_usage=${cpu_usage%.*}
    test_case "CPU 使用率正常 (<80%)" "[ ${cpu_usage:-100} -lt 80 ]"
    
    # 内存使用率测试
    local memory_usage=$(free | grep Mem | awk '{printf("%.0f\n", $3/$2 * 100.0)}')
    test_case "内存使用率正常 (<85%)" "[ ${memory_usage:-100} -lt 85 ]"
    
    # 磁盘 IO 测试
    local io_wait=$(top -bn1 | grep "Cpu(s)" | awk '{print $5}' | awk -F'%' '{print $1}' | cut -d'w' -f1)
    io_wait=${io_wait%.*}
    test_case "磁盘 IO 等待正常 (<20%)" "[ ${io_wait:-0} -lt 20 ]"
}

# 9. 安全配置测试
test_security_configuration() {
    log "INFO" "=== 安全配置测试 ==="
    
    # 测试默认密码是否已修改
    if [ -f ".env" ]; then
        test_case "MoviePilot 密码已修改" "! grep -q 'password123' .env"
        test_case "qBittorrent 密码已修改" "! grep -q 'adminpass' .env"
    fi
    
    # 测试文件权限
    test_case "配置文件权限安全" "[ $(stat -c '%a' .env 2>/dev/null || echo '644') -le 644 ]"
    
    # 测试防火墙状态
    if command -v ufw >/dev/null; then
        test_case "防火墙已启用" "ufw status | grep -q 'Status: active'"
    fi
}

# 10. 备份恢复测试
test_backup_recovery() {
    log "INFO" "=== 备份恢复测试 ==="
    
    # 测试备份脚本存在
    test_case "备份脚本存在" "[ -f './scripts/backup.sh' ]"
    
    # 测试备份目录
    test_case "备份目录存在" "[ -d '$BASE_DIR/backup' ]"
    
    # 模拟备份测试（不执行实际备份）
    if [ -f "./scripts/backup.sh" ]; then
        test_case "备份脚本可执行" "[ -x './scripts/backup.sh' ]"
    fi
}

# 生成测试报告
generate_test_report() {
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                            测试结果报告                                     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n📊 ${YELLOW}测试统计${NC}"
    echo -e "总测试数: $TESTS_TOTAL"
    echo -e "通过数: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "失败数: ${RED}$TESTS_FAILED${NC}"
    echo -e "成功率: ${GREEN}$success_rate%${NC}"
    
    echo -e "\n⏰ ${YELLOW}测试时间${NC}"
    echo -e "结束时间: $end_time"
    
    echo -e "\n📄 ${YELLOW}详细日志${NC}"
    echo -e "日志文件: $TEST_LOG"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n🎉 ${GREEN}所有测试通过！系统运行正常。${NC}"
        return 0
    else
        echo -e "\n⚠️  ${RED}发现 $TESTS_FAILED 个问题，请检查日志文件。${NC}"
        return 1
    fi
}

# 主函数
main() {
    # 显示测试横幅
    show_test_banner
    
    # 执行测试套件
    test_basic_environment
    test_network_connectivity
    test_container_services
    test_web_services
    test_api_interfaces
    test_data_storage
    test_service_integration
    test_performance_baseline
    test_security_configuration
    test_backup_recovery
    
    # 生成测试报告
    generate_test_report
}

# 使用说明
show_usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help          显示帮助信息"
    echo "  -q, --quick         快速测试（仅核心功能）"
    echo "  -v, --verbose       详细输出"
    echo "  --basic-only        仅基础环境测试"
    echo "  --network-only      仅网络测试"
    echo "  --services-only     仅服务测试"
}

# 快速测试模式
quick_test() {
    show_test_banner
    test_basic_environment
    test_container_services
    test_web_services
    generate_test_report
}

# 参数解析
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    -q|--quick)
        quick_test
        ;;
    --basic-only)
        show_test_banner
        test_basic_environment
        generate_test_report
        ;;
    --network-only)
        show_test_banner
        test_network_connectivity
        generate_test_report
        ;;
    --services-only)
        show_test_banner
        test_container_services
        test_web_services
        generate_test_report
        ;;
    *)
        main "$@"
        ;;
esac