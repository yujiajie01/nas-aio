#!/bin/bash

# =============================================================================
# NAS 自动化系统 - 测试套件执行脚本
# =============================================================================

set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 脚本目录
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TESTS_DIR="$SCRIPT_DIR/tests"
readonly REPORT_DIR="/tmp/nas-test-reports"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 测试结果统计
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# 初始化测试环境
init_test_environment() {
    echo -e "${BLUE}[INIT]${NC} 初始化测试环境..."
    
    # 创建报告目录
    mkdir -p "$REPORT_DIR"
    
    # 设置脚本执行权限
    find "$TESTS_DIR" -name "*.sh" -exec chmod +x {} \;
    
    echo -e "${GREEN}[INIT]${NC} 测试环境初始化完成"
}

# 显示测试套件横幅
show_test_banner() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    NAS 自动化系统 - 完整测试套件                            ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "测试开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "报告保存目录: $REPORT_DIR"
    echo
}

# 执行单个测试套件
run_test_suite() {
    local suite_name="$1"
    local test_script="$2"
    local report_file="$REPORT_DIR/${suite_name}_${TIMESTAMP}.log"
    
    echo -e "${YELLOW}[TEST]${NC} 执行测试套件: $suite_name"
    
    ((TOTAL_SUITES++))
    
    if [ -f "$test_script" ] && [ -x "$test_script" ]; then
        local start_time=$(date +%s)
        
        if "$test_script" > "$report_file" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            echo -e "${GREEN}[PASS]${NC} $suite_name (耗时: ${duration}s)"
            ((PASSED_SUITES++))
            return 0
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            echo -e "${RED}[FAIL]${NC} $suite_name (耗时: ${duration}s)"
            echo -e "       详细错误请查看: $report_file"
            ((FAILED_SUITES++))
            return 1
        fi
    else
        echo -e "${RED}[ERROR]${NC} 测试脚本不存在或不可执行: $test_script"
        ((FAILED_SUITES++))
        return 1
    fi
}

# 完整测试套件
run_full_test_suite() {
    echo -e "${BLUE}=== 执行完整测试套件 ===${NC}\n"
    
    # 1. 单元测试
    run_test_suite "单元测试" "$TESTS_DIR/unit-tests.sh"
    
    # 2. 系统集成测试
    run_test_suite "系统集成测试" "$TESTS_DIR/system-test.sh"
    
    # 3. 性能测试
    run_test_suite "性能测试" "$TESTS_DIR/performance-test.sh"
    
    echo
}

# 快速测试套件
run_quick_test_suite() {
    echo -e "${BLUE}=== 执行快速测试套件 ===${NC}\n"
    
    # 1. 单元测试（配置相关）
    run_test_suite "配置测试" "$TESTS_DIR/unit-tests.sh --config"
    
    # 2. 系统基础测试
    run_test_suite "基础系统测试" "$TESTS_DIR/system-test.sh --quick"
    
    # 3. 快速性能检查
    run_test_suite "快速性能检查" "$TESTS_DIR/performance-test.sh --quick"
    
    echo
}

# 安装验证测试
run_installation_test() {
    echo -e "${BLUE}=== 执行安装验证测试 ===${NC}\n"
    
    # 验证基础环境
    run_test_suite "基础环境验证" "$TESTS_DIR/system-test.sh --basic-only"
    
    # 验证网络配置
    run_test_suite "网络配置验证" "$TESTS_DIR/system-test.sh --network-only"
    
    # 验证服务状态
    run_test_suite "服务状态验证" "$TESTS_DIR/system-test.sh --services-only"
    
    echo
}

# 持续监控测试
run_monitoring_test() {
    echo -e "${BLUE}=== 执行持续监控测试 ===${NC}\n"
    
    # 系统性能监控
    run_test_suite "系统性能监控" "$TESTS_DIR/performance-test.sh --cpu --memory"
    
    # 服务可用性监控
    run_test_suite "服务可用性监控" "$TESTS_DIR/system-test.sh --services-only"
    
    echo
}

# 生成测试总结报告
generate_summary_report() {
    local summary_file="$REPORT_DIR/test_summary_${TIMESTAMP}.txt"
    local success_rate=0
    
    if [ $TOTAL_SUITES -gt 0 ]; then
        success_rate=$((PASSED_SUITES * 100 / TOTAL_SUITES))
    fi
    
    cat > "$summary_file" << EOF
NAS 自动化系统测试总结报告
==========================

测试执行时间: $(date '+%Y-%m-%d %H:%M:%S')
测试报告目录: $REPORT_DIR

测试统计:
- 总测试套件数: $TOTAL_SUITES
- 通过套件数: $PASSED_SUITES
- 失败套件数: $FAILED_SUITES
- 成功率: $success_rate%

详细测试报告:
EOF
    
    # 添加各个测试套件的详细信息
    for report in "$REPORT_DIR"/*_${TIMESTAMP}.log; do
        if [ -f "$report" ]; then
            local suite_name=$(basename "$report" "_${TIMESTAMP}.log")
            echo "- $suite_name: $report" >> "$summary_file"
        fi
    done
    
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                              测试总结报告                                   ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n📊 ${YELLOW}测试结果统计${NC}"
    echo -e "总测试套件数: $TOTAL_SUITES"
    echo -e "通过套件数: ${GREEN}$PASSED_SUITES${NC}"
    echo -e "失败套件数: ${RED}$FAILED_SUITES${NC}"
    echo -e "成功率: ${GREEN}$success_rate%${NC}"
    
    echo -e "\n📄 ${YELLOW}详细报告位置${NC}"
    echo -e "总结报告: $summary_file"
    echo -e "详细日志: $REPORT_DIR/"
    
    if [ $FAILED_SUITES -eq 0 ]; then
        echo -e "\n🎉 ${GREEN}所有测试套件通过！系统状态良好。${NC}"
        return 0
    else
        echo -e "\n⚠️  ${RED}有 $FAILED_SUITES 个测试套件失败，请检查详细日志。${NC}"
        return 1
    fi
}

# 清理旧的测试报告
cleanup_old_reports() {
    echo -e "${BLUE}[CLEANUP]${NC} 清理7天前的旧测试报告..."
    
    if [ -d "$REPORT_DIR" ]; then
        find "$REPORT_DIR" -name "*.log" -mtime +7 -delete
        find "$REPORT_DIR" -name "*.txt" -mtime +7 -delete
        echo -e "${GREEN}[CLEANUP]${NC} 清理完成"
    fi
}

# 发送测试报告（可扩展）
send_test_report() {
    local report_file="$1"
    
    # 这里可以集成邮件发送、微信通知等功能
    # 示例：发送到邮箱
    # mail -s "NAS系统测试报告" admin@example.com < "$report_file"
    
    # 示例：发送到微信
    # curl -X POST "webhook_url" -d "@$report_file"
    
    echo -e "${BLUE}[REPORT]${NC} 测试报告已准备就绪: $report_file"
}

# 使用说明
show_usage() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help          显示帮助信息"
    echo "  -f, --full          执行完整测试套件（默认）"
    echo "  -q, --quick         执行快速测试套件"
    echo "  -i, --install       执行安装验证测试"
    echo "  -m, --monitor       执行持续监控测试"
    echo "  -c, --cleanup       清理旧的测试报告"
    echo "  --unit              仅执行单元测试"
    echo "  --system            仅执行系统测试"
    echo "  --performance       仅执行性能测试"
    echo
    echo "示例:"
    echo "  $0                  # 执行完整测试套件"
    echo "  $0 --quick          # 执行快速测试"
    echo "  $0 --install        # 验证安装状态"
    echo "  $0 --monitor        # 监控系统状态"
}

# 主函数
main() {
    # 初始化
    init_test_environment
    show_test_banner
    cleanup_old_reports
    
    # 根据参数执行相应的测试
    case "${1:-full}" in
        -f|--full|full)
            run_full_test_suite
            ;;
        -q|--quick|quick)
            run_quick_test_suite
            ;;
        -i|--install|install)
            run_installation_test
            ;;
        -m|--monitor|monitor)
            run_monitoring_test
            ;;
        --unit)
            run_test_suite "单元测试" "$TESTS_DIR/unit-tests.sh"
            ;;
        --system)
            run_test_suite "系统测试" "$TESTS_DIR/system-test.sh"
            ;;
        --performance)
            run_test_suite "性能测试" "$TESTS_DIR/performance-test.sh"
            ;;
        -c|--cleanup)
            cleanup_old_reports
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} 未知选项: $1"
            show_usage
            exit 1
            ;;
    esac
    
    # 生成总结报告
    generate_summary_report
    local exit_code=$?
    
    # 发送报告（如果配置了通知）
    local summary_file="$REPORT_DIR/test_summary_${TIMESTAMP}.txt"
    send_test_report "$summary_file"
    
    # 返回测试结果
    exit $exit_code
}

# 执行主函数
main "$@"