#!/bin/bash

# =============================================================================
# NAS 自动化系统 - 性能测试脚本
# =============================================================================

set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 测试配置
readonly TEST_DURATION=60  # 测试持续时间（秒）
readonly SAMPLE_INTERVAL=5  # 采样间隔（秒）
readonly REPORT_FILE="/tmp/nas-performance-report.txt"

# 性能阈值
readonly CPU_THRESHOLD=80
readonly MEMORY_THRESHOLD=85
readonly DISK_IO_THRESHOLD=80
readonly NETWORK_THRESHOLD=500  # Mbps

# 全局变量
START_TIME=""
END_TIME=""

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$REPORT_FILE"
            ;;
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $message" | tee -a "$REPORT_FILE"
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message" | tee -a "$REPORT_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$REPORT_FILE"
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$REPORT_FILE"
}

# 显示性能测试横幅
show_performance_banner() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                       NAS 自动化系统 - 性能测试                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log "INFO" "开始性能测试..."
    log "INFO" "测试持续时间: ${TEST_DURATION}秒"
    log "INFO" "采样间隔: ${SAMPLE_INTERVAL}秒"
    START_TIME=$(date +%s)
}

# 获取系统信息
get_system_info() {
    log "INFO" "=== 系统信息 ==="
    
    # CPU 信息
    local cpu_info=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local cpu_cores=$(nproc)
    log "INFO" "CPU: $cpu_info"
    log "INFO" "CPU 核心数: $cpu_cores"
    
    # 内存信息
    local total_mem=$(free -h | grep Mem | awk '{print $2}')
    log "INFO" "总内存: $total_mem"
    
    # 磁盘信息
    log "INFO" "磁盘使用情况:"
    df -h | grep -E '^/dev/' | while read line; do
        log "INFO" "  $line"
    done
    
    # Docker 信息
    if command -v docker >/dev/null 2>&1; then
        local docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
        log "INFO" "Docker 版本: $docker_version"
        
        local running_containers=$(docker ps --format "table {{.Names}}" | tail -n +2 | wc -l)
        log "INFO" "运行中的容器数: $running_containers"
    fi
}

# CPU 性能测试
test_cpu_performance() {
    log "INFO" "=== CPU 性能测试 ==="
    
    local cpu_samples=()
    local test_iterations=$((TEST_DURATION / SAMPLE_INTERVAL))
    
    for ((i=1; i<=test_iterations; i++)); do
        # 获取 CPU 使用率
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
        cpu_usage=${cpu_usage%.*}  # 去除小数部分
        cpu_samples+=($cpu_usage)
        
        log "INFO" "CPU 使用率 (${i}/${test_iterations}): ${cpu_usage}%"
        
        if [ $i -lt $test_iterations ]; then
            sleep $SAMPLE_INTERVAL
        fi
    done
    
    # 计算统计信息
    local cpu_avg=$(printf '%s\n' "${cpu_samples[@]}" | awk '{sum+=$1} END {printf "%.1f", sum/NR}')
    local cpu_max=$(printf '%s\n' "${cpu_samples[@]}" | sort -nr | head -1)
    local cpu_min=$(printf '%s\n' "${cpu_samples[@]}" | sort -n | head -1)
    
    log "INFO" "CPU 使用率统计:"
    log "INFO" "  平均: ${cpu_avg}%"
    log "INFO" "  最大: ${cpu_max}%"
    log "INFO" "  最小: ${cpu_min}%"
    
    # 性能评估
    if (( $(echo "$cpu_avg < $CPU_THRESHOLD" | bc -l) )); then
        log "PASS" "CPU 性能正常 (平均使用率: ${cpu_avg}%)"
    else
        log "FAIL" "CPU 使用率过高 (平均使用率: ${cpu_avg}%，阈值: ${CPU_THRESHOLD}%)"
    fi
}

# 内存性能测试
test_memory_performance() {
    log "INFO" "=== 内存性能测试 ==="
    
    local memory_samples=()
    local test_iterations=$((TEST_DURATION / SAMPLE_INTERVAL))
    
    for ((i=1; i<=test_iterations; i++)); do
        # 获取内存使用率
        local memory_info=$(free | grep Mem)
        local total_memory=$(echo $memory_info | awk '{print $2}')
        local used_memory=$(echo $memory_info | awk '{print $3}')
        local memory_usage=$((used_memory * 100 / total_memory))
        
        memory_samples+=($memory_usage)
        
        log "INFO" "内存使用率 (${i}/${test_iterations}): ${memory_usage}%"
        
        if [ $i -lt $test_iterations ]; then
            sleep $SAMPLE_INTERVAL
        fi
    done
    
    # 计算统计信息
    local mem_avg=$(printf '%s\n' "${memory_samples[@]}" | awk '{sum+=$1} END {printf "%.1f", sum/NR}')
    local mem_max=$(printf '%s\n' "${memory_samples[@]}" | sort -nr | head -1)
    local mem_min=$(printf '%s\n' "${memory_samples[@]}" | sort -n | head -1)
    
    log "INFO" "内存使用率统计:"
    log "INFO" "  平均: ${mem_avg}%"
    log "INFO" "  最大: ${mem_max}%"
    log "INFO" "  最小: ${mem_min}%"
    
    # 性能评估
    if (( $(echo "$mem_avg < $MEMORY_THRESHOLD" | bc -l) )); then
        log "PASS" "内存性能正常 (平均使用率: ${mem_avg}%)"
    else
        log "FAIL" "内存使用率过高 (平均使用率: ${mem_avg}%，阈值: ${MEMORY_THRESHOLD}%)"
    fi
}

# 磁盘 I/O 性能测试
test_disk_performance() {
    log "INFO" "=== 磁盘 I/O 性能测试 ==="
    
    # 测试目录
    local test_dir="/opt/nas-data"
    if [ ! -d "$test_dir" ]; then
        test_dir="/tmp"
    fi
    
    # 写入性能测试 (100MB 文件)
    log "INFO" "测试磁盘写入性能..."
    local write_start=$(date +%s.%N)
    dd if=/dev/zero of="$test_dir/disk_write_test.tmp" bs=1M count=100 oflag=sync 2>/dev/null
    local write_end=$(date +%s.%N)
    local write_time=$(echo "$write_end - $write_start" | bc)
    local write_speed=$(echo "scale=1; 100 / $write_time" | bc)
    
    log "INFO" "写入速度: ${write_speed} MB/s"
    
    # 读取性能测试
    log "INFO" "测试磁盘读取性能..."
    local read_start=$(date +%s.%N)
    dd if="$test_dir/disk_write_test.tmp" of=/dev/null bs=1M 2>/dev/null
    local read_end=$(date +%s.%N)
    local read_time=$(echo "$read_end - $read_start" | bc)
    local read_speed=$(echo "scale=1; 100 / $read_time" | bc)
    
    log "INFO" "读取速度: ${read_speed} MB/s"
    
    # 清理测试文件
    rm -f "$test_dir/disk_write_test.tmp"
    
    # 磁盘 I/O 等待监控
    local io_samples=()
    local test_iterations=10
    
    for ((i=1; i<=test_iterations; i++)); do
        local io_wait=$(top -bn1 | grep "Cpu(s)" | awk '{print $5}' | awk -F'%' '{print $1}' | cut -d'w' -f1)
        io_wait=${io_wait%.*}
        io_samples+=($io_wait)
        
        if [ $i -lt $test_iterations ]; then
            sleep 2
        fi
    done
    
    local io_avg=$(printf '%s\n' "${io_samples[@]}" | awk '{sum+=$1} END {printf "%.1f", sum/NR}')
    
    log "INFO" "磁盘 I/O 等待: ${io_avg}%"
    
    # 性能评估
    if (( $(echo "$write_speed > 50" | bc -l) )) && (( $(echo "$read_speed > 50" | bc -l) )); then
        log "PASS" "磁盘 I/O 性能正常 (写: ${write_speed}MB/s, 读: ${read_speed}MB/s)"
    else
        log "WARN" "磁盘 I/O 性能较低 (写: ${write_speed}MB/s, 读: ${read_speed}MB/s)"
    fi
}

# 网络性能测试
test_network_performance() {
    log "INFO" "=== 网络性能测试 ==="
    
    # 测试网络延迟
    log "INFO" "测试网络延迟..."
    local ping_result=$(ping -c 10 8.8.8.8 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
    if [ -n "$ping_result" ]; then
        log "INFO" "平均延迟: ${ping_result}ms"
        
        if (( $(echo "$ping_result < 50" | bc -l) )); then
            log "PASS" "网络延迟正常"
        else
            log "WARN" "网络延迟较高: ${ping_result}ms"
        fi
    else
        log "WARN" "无法测试网络延迟"
    fi
    
    # 测试网络连接数
    local connections=$(netstat -tun 2>/dev/null | grep -c ESTABLISHED)
    log "INFO" "当前网络连接数: $connections"
    
    # 测试关键端口响应时间
    local ports=(3000 8001 8096 8080 9091)
    for port in "${ports[@]}"; do
        local response_time=$(curl -o /dev/null -s -w '%{time_total}' --connect-timeout 5 "http://localhost:$port" 2>/dev/null || echo "timeout")
        if [ "$response_time" != "timeout" ]; then
            local response_ms=$(echo "$response_time * 1000" | bc)
            log "INFO" "端口 $port 响应时间: ${response_ms}ms"
        else
            log "WARN" "端口 $port 无响应"
        fi
    done
}

# 容器性能测试
test_container_performance() {
    log "INFO" "=== 容器性能测试 ==="
    
    if ! command -v docker >/dev/null 2>&1; then
        log "WARN" "Docker 不可用，跳过容器性能测试"
        return
    fi
    
    # 获取运行中的容器
    local containers=$(docker ps --format "{{.Names}}" | head -10)
    
    if [ -z "$containers" ]; then
        log "WARN" "没有运行中的容器"
        return
    fi
    
    log "INFO" "容器资源使用情况:"
    
    # 获取容器统计信息
    local stats_output=$(timeout 10 docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" $containers 2>/dev/null || echo "timeout")
    
    if [ "$stats_output" != "timeout" ]; then
        echo "$stats_output" | while IFS=$'\t' read name cpu mem net block; do
            if [ "$name" != "NAME" ]; then
                log "INFO" "  $name: CPU=${cpu}, MEM=${mem}, NET=${net}, DISK=${block}"
            fi
        done
    else
        log "WARN" "获取容器统计信息超时"
    fi
    
    # 检查容器健康状态
    local unhealthy_containers=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" | wc -l)
    if [ "$unhealthy_containers" -eq 0 ]; then
        log "PASS" "所有容器健康状态正常"
    else
        log "FAIL" "发现 $unhealthy_containers 个不健康的容器"
    fi
}

# 负载测试
test_load_performance() {
    log "INFO" "=== 负载测试 ==="
    
    # 系统负载
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local load_per_core=$(echo "scale=2; $load_avg / $cpu_cores" | bc)
    
    log "INFO" "系统负载: $load_avg (每核心: $load_per_core)"
    
    if (( $(echo "$load_per_core < 1.0" | bc -l) )); then
        log "PASS" "系统负载正常"
    elif (( $(echo "$load_per_core < 2.0" | bc -l) )); then
        log "WARN" "系统负载较高"
    else
        log "FAIL" "系统负载过高"
    fi
    
    # 模拟并发访问测试
    if command -v curl >/dev/null 2>&1; then
        log "INFO" "执行并发访问测试..."
        
        local test_url="http://localhost:3000"
        local concurrent_requests=10
        local total_requests=100
        
        # 使用后台进程模拟并发
        local pids=()
        local start_time=$(date +%s.%N)
        
        for ((i=1; i<=concurrent_requests; i++)); do
            {
                for ((j=1; j<=total_requests/concurrent_requests; j++)); do
                    curl -s -o /dev/null "$test_url" 2>/dev/null || true
                done
            } &
            pids+=($!)
        done
        
        # 等待所有请求完成
        for pid in "${pids[@]}"; do
            wait $pid
        done
        
        local end_time=$(date +%s.%N)
        local total_time=$(echo "$end_time - $start_time" | bc)
        local requests_per_second=$(echo "scale=1; $total_requests / $total_time" | bc)
        
        log "INFO" "并发测试结果: ${requests_per_second} 请求/秒"
        
        if (( $(echo "$requests_per_second > 10" | bc -l) )); then
            log "PASS" "并发处理能力正常"
        else
            log "WARN" "并发处理能力较低"
        fi
    fi
}

# 生成性能报告
generate_performance_report() {
    END_TIME=$(date +%s)
    local test_duration=$((END_TIME - START_TIME))
    
    log "INFO" "=== 性能测试报告 ==="
    log "INFO" "测试持续时间: ${test_duration}秒"
    log "INFO" "报告生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 系统资源概况
    local current_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    local current_mem=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
    local current_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    log "INFO" "当前系统状态:"
    log "INFO" "  CPU 使用率: ${current_cpu%.*}%"
    log "INFO" "  内存使用率: ${current_mem}%"
    log "INFO" "  系统负载: $current_load"
    
    # 磁盘使用情况
    log "INFO" "磁盘使用情况:"
    df -h | grep -E '^/dev/' | while read line; do
        log "INFO" "  $line"
    done
    
    # 网络状态
    local active_connections=$(netstat -tun 2>/dev/null | grep -c ESTABLISHED)
    log "INFO" "活跃网络连接: $active_connections"
    
    # 容器状态
    if command -v docker >/dev/null 2>&1; then
        local running_containers=$(docker ps --format "{{.Names}}" | wc -l)
        local total_containers=$(docker ps -a --format "{{.Names}}" | wc -l)
        log "INFO" "容器状态: $running_containers/$total_containers 运行中"
    fi
    
    log "INFO" "详细报告已保存到: $REPORT_FILE"
}

# 快速性能检查
quick_performance_check() {
    log "INFO" "=== 快速性能检查 ==="
    
    # CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    log "INFO" "CPU 使用率: ${cpu_usage%.*}%"
    
    # 内存
    local mem_usage=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
    log "INFO" "内存使用率: ${mem_usage}%"
    
    # 磁盘
    local disk_usage=$(df / | awk 'NR==2 {print $5}')
    log "INFO" "根分区使用率: $disk_usage"
    
    # 负载
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    log "INFO" "系统负载: $load_avg"
    
    # 服务状态
    local important_ports=(3000 8001 8096 8080)
    local services_up=0
    for port in "${important_ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            ((services_up++))
        fi
    done
    log "INFO" "关键服务状态: $services_up/${#important_ports[@]} 正常"
}

# 主函数
main() {
    # 初始化报告文件
    echo "NAS 自动化系统性能测试报告" > "$REPORT_FILE"
    echo "==============================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    show_performance_banner
    get_system_info
    test_cpu_performance
    test_memory_performance
    test_disk_performance
    test_network_performance
    test_container_performance
    test_load_performance
    generate_performance_report
    
    echo -e "\n${GREEN}性能测试完成！详细报告: $REPORT_FILE${NC}"
}

# 使用说明
show_usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help      显示帮助信息"
    echo "  -q, --quick     快速性能检查"
    echo "  -c, --cpu       仅 CPU 性能测试"
    echo "  -m, --memory    仅内存性能测试"
    echo "  -d, --disk      仅磁盘性能测试"
    echo "  -n, --network   仅网络性能测试"
    echo "  -t, --time N    设置测试持续时间（秒，默认60）"
}

# 参数解析
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    -q|--quick)
        echo "NAS 自动化系统快速性能检查" > "$REPORT_FILE"
        echo "============================" >> "$REPORT_FILE"
        quick_performance_check
        ;;
    -c|--cpu)
        show_performance_banner
        test_cpu_performance
        ;;
    -m|--memory)
        show_performance_banner
        test_memory_performance
        ;;
    -d|--disk)
        show_performance_banner
        test_disk_performance
        ;;
    -n|--network)
        show_performance_banner
        test_network_performance
        ;;
    *)
        main "$@"
        ;;
esac