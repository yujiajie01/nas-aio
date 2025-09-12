#!/bin/bash

# =============================================================================
# NAS 自动化系统 - 单元测试脚本
# =============================================================================

set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 测试配置
readonly TEST_DIR="/tmp/nas-unit-tests"
readonly MOCK_DATA_DIR="$TEST_DIR/mock_data"

# 测试统计
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# 初始化测试环境
setup_test_env() {
    echo -e "${BLUE}[SETUP]${NC} 初始化测试环境..."
    
    # 创建测试目录
    mkdir -p "$TEST_DIR"
    mkdir -p "$MOCK_DATA_DIR"
    
    # 创建模拟数据
    create_mock_data
    
    echo -e "${GREEN}[SETUP]${NC} 测试环境初始化完成"
}

# 清理测试环境
cleanup_test_env() {
    echo -e "${BLUE}[CLEANUP]${NC} 清理测试环境..."
    rm -rf "$TEST_DIR"
    echo -e "${GREEN}[CLEANUP]${NC} 清理完成"
}

# 创建模拟数据
create_mock_data() {
    # 模拟配置文件
    cat > "$MOCK_DATA_DIR/.env" << 'EOF'
PUID=1000
PGID=1000
TZ=Asia/Shanghai
MOVIEPILOT_SUPERUSER=admin
MOVIEPILOT_SUPERUSER_PASSWORD=testpass123
QB_USERNAME=admin
QB_WEBUI_PASSWORD=testpass123
EOF

    # 模拟 Docker Compose 文件
    cat > "$MOCK_DATA_DIR/docker-compose.test.yml" << 'EOF'
version: '3.8'
services:
  test-service:
    image: nginx:alpine
    ports:
      - "8888:80"
EOF

    # 模拟媒体文件
    mkdir -p "$MOCK_DATA_DIR/media/movies"
    mkdir -p "$MOCK_DATA_DIR/media/tv"
    touch "$MOCK_DATA_DIR/media/movies/test_movie.mp4"
    touch "$MOCK_DATA_DIR/media/tv/test_tv_show.mkv"
}

# 测试断言函数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    ((TESTS_RUN++))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name - Expected: '$expected', Got: '$actual'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local test_name="$2"
    
    ((TESTS_RUN++))
    
    if eval "$condition"; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name - Condition failed: $condition"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local test_name="$2"
    
    assert_true "[ -f '$file_path' ]" "$test_name"
}

assert_dir_exists() {
    local dir_path="$1"
    local test_name="$2"
    
    assert_true "[ -d '$dir_path' ]" "$test_name"
}

# 配置文件测试
test_config_parsing() {
    echo -e "\n${YELLOW}=== 配置文件解析测试 ===${NC}"
    
    # 测试环境变量解析
    source "$MOCK_DATA_DIR/.env"
    
    assert_equals "1000" "$PUID" "PUID 配置解析"
    assert_equals "Asia/Shanghai" "$TZ" "时区配置解析"
    assert_equals "admin" "$MOVIEPILOT_SUPERUSER" "MoviePilot 用户名解析"
    
    # 测试密码验证
    assert_true "[ ${#MOVIEPILOT_SUPERUSER_PASSWORD} -ge 8 ]" "密码长度验证"
    assert_true "[[ '$MOVIEPILOT_SUPERUSER_PASSWORD' != 'password123' ]]" "默认密码检查"
}

# 目录结构测试
test_directory_structure() {
    echo -e "\n${YELLOW}=== 目录结构测试 ===${NC}"
    
    # 创建测试目录结构
    local test_base_dir="$TEST_DIR/nas-data"
    mkdir -p "$test_base_dir"/{downloads,media,config,logs}
    mkdir -p "$test_base_dir/media"/{movies,tv,music}
    mkdir -p "$test_base_dir/downloads"/{complete,incomplete,watch}
    
    # 测试目录存在性
    assert_dir_exists "$test_base_dir/downloads" "下载目录存在"
    assert_dir_exists "$test_base_dir/media" "媒体目录存在"
    assert_dir_exists "$test_base_dir/config" "配置目录存在"
    assert_dir_exists "$test_base_dir/media/movies" "电影目录存在"
    assert_dir_exists "$test_base_dir/media/tv" "电视剧目录存在"
    
    # 测试目录权限
    chmod 755 "$test_base_dir/media"
    chmod 777 "$test_base_dir/downloads"
    
    local media_perm=$(stat -c "%a" "$test_base_dir/media")
    local download_perm=$(stat -c "%a" "$test_base_dir/downloads")
    
    assert_equals "755" "$media_perm" "媒体目录权限"
    assert_equals "777" "$download_perm" "下载目录权限"
}

# Docker Compose 配置测试
test_docker_compose_config() {
    echo -e "\n${YELLOW}=== Docker Compose 配置测试 ===${NC}"
    
    # 测试配置文件语法
    if command -v docker-compose >/dev/null 2>&1; then
        assert_true "docker-compose -f '$MOCK_DATA_DIR/docker-compose.test.yml' config -q" "Docker Compose 配置语法"
    else
        echo -e "${YELLOW}[SKIP]${NC} Docker Compose 配置测试 - 命令不可用"
    fi
    
    # 测试端口配置
    local port_config=$(grep -o '"[0-9]*:[0-9]*"' "$MOCK_DATA_DIR/docker-compose.test.yml" | head -1)
    assert_true "[ -n '$port_config' ]" "端口映射配置"
}

# 网络连接测试
test_network_functions() {
    echo -e "\n${YELLOW}=== 网络功能测试 ===${NC}"
    
    # 测试 URL 验证函数
    validate_url() {
        local url="$1"
        if [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+:[0-9]+/?$ ]]; then
            return 0
        else
            return 1
        fi
    }
    
    assert_true "validate_url 'http://localhost:8080'" "URL 格式验证"
    assert_true "! validate_url 'invalid-url'" "无效 URL 检测"
    
    # 测试端口检查函数
    check_port_available() {
        local port="$1"
        ! netstat -tuln 2>/dev/null | grep -q ":$port "
    }
    
    # 使用一个不太可能被占用的端口进行测试
    assert_true "check_port_available 65432" "端口可用性检查"
}

# 文件操作测试
test_file_operations() {
    echo -e "\n${YELLOW}=== 文件操作测试 ===${NC}"
    
    # 测试文件复制
    local source_file="$MOCK_DATA_DIR/.env"
    local target_file="$TEST_DIR/.env.copy"
    
    cp "$source_file" "$target_file"
    assert_file_exists "$target_file" "文件复制操作"
    
    # 测试文件内容一致性
    local source_md5=$(md5sum "$source_file" | cut -d' ' -f1)
    local target_md5=$(md5sum "$target_file" | cut -d' ' -f1)
    assert_equals "$source_md5" "$target_md5" "文件内容一致性"
    
    # 测试文件权限设置
    chmod 644 "$target_file"
    local file_perm=$(stat -c "%a" "$target_file")
    assert_equals "644" "$file_perm" "文件权限设置"
}

# 日志处理测试
test_logging_functions() {
    echo -e "\n${YELLOW}=== 日志处理测试 ===${NC}"
    
    # 创建日志处理函数
    write_log() {
        local level="$1"
        local message="$2"
        local log_file="$3"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$log_file"
    }
    
    local test_log_file="$TEST_DIR/test.log"
    
    # 测试日志写入
    write_log "INFO" "Test message" "$test_log_file"
    assert_file_exists "$test_log_file" "日志文件创建"
    
    # 测试日志内容
    assert_true "grep -q 'Test message' '$test_log_file'" "日志内容写入"
    assert_true "grep -q 'INFO' '$test_log_file'" "日志级别记录"
    
    # 测试日志格式
    local log_line=$(head -1 "$test_log_file")
    assert_true "[[ '$log_line' =~ ^\[[0-9-]+ [0-9:]+\] ]]" "日志时间戳格式"
}

# 配置验证测试
test_config_validation() {
    echo -e "\n${YELLOW}=== 配置验证测试 ===${NC}"
    
    # 端口范围验证
    validate_port() {
        local port="$1"
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
            return 0
        else
            return 1
        fi
    }
    
    assert_true "validate_port 8080" "有效端口验证"
    assert_true "! validate_port 70000" "无效端口检测"
    assert_true "! validate_port 'abc'" "非数字端口检测"
    
    # 内存大小验证
    validate_memory() {
        local memory="$1"
        if [[ "$memory" =~ ^[0-9]+[GMgm]?$ ]]; then
            return 0
        else
            return 1
        fi
    }
    
    assert_true "validate_memory '8G'" "内存格式验证"
    assert_true "validate_memory '1024M'" "内存格式验证"
    assert_true "! validate_memory 'invalid'" "无效内存格式检测"
}

# 错误处理测试
test_error_handling() {
    echo -e "\n${YELLOW}=== 错误处理测试 ===${NC}"
    
    # 测试异常情况处理
    safe_mkdir() {
        local dir="$1"
        if [ ! -d "$dir" ]; then
            if mkdir -p "$dir" 2>/dev/null; then
                return 0
            else
                return 1
            fi
        fi
        return 0
    }
    
    assert_true "safe_mkdir '$TEST_DIR/new_dir'" "安全目录创建"
    assert_true "safe_mkdir '/invalid/path/that/cannot/be/created'" "创建失败处理" || true
    
    # 测试文件存在性检查
    check_required_files() {
        local files=("$@")
        for file in "${files[@]}"; do
            if [ ! -f "$file" ]; then
                return 1
            fi
        done
        return 0
    }
    
    touch "$TEST_DIR/required1.txt" "$TEST_DIR/required2.txt"
    assert_true "check_required_files '$TEST_DIR/required1.txt' '$TEST_DIR/required2.txt'" "必需文件检查"
    assert_true "! check_required_files '$TEST_DIR/nonexistent.txt'" "缺失文件检测"
}

# 性能测试
test_performance() {
    echo -e "\n${YELLOW}=== 性能测试 ===${NC}"
    
    # 文件操作性能测试
    local start_time=$(date +%s)
    
    # 创建1000个小文件
    for i in {1..1000}; do
        echo "test content $i" > "$TEST_DIR/perf_test_$i.txt"
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 性能应该在合理范围内（少于10秒）
    assert_true "[ $duration -lt 10 ]" "文件创建性能测试"
    
    # 清理性能测试文件
    rm -f "$TEST_DIR"/perf_test_*.txt
}

# 集成测试
test_integration() {
    echo -e "\n${YELLOW}=== 集成测试 ===${NC}"
    
    # 模拟完整的配置生成流程
    local config_dir="$TEST_DIR/integration_config"
    mkdir -p "$config_dir"
    
    # 生成配置文件
    cat > "$config_dir/.env" << EOF
PUID=1000
PGID=1000
TZ=Asia/Shanghai
DATA_PATH=$TEST_DIR/integration_data
MOVIEPILOT_SUPERUSER=testuser
MOVIEPILOT_SUPERUSER_PASSWORD=integration_test_pass
EOF
    
    # 创建数据目录
    source "$config_dir/.env"
    mkdir -p "$DATA_PATH"/{media,downloads,config}
    
    # 验证集成结果
    assert_file_exists "$config_dir/.env" "集成配置文件生成"
    assert_dir_exists "$DATA_PATH" "集成数据目录创建"
    assert_equals "testuser" "$MOVIEPILOT_SUPERUSER" "集成配置变量"
}

# 运行所有测试
run_all_tests() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                        NAS 自动化系统 - 单元测试                            ║${NC}" 
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    # 初始化测试环境
    setup_test_env
    
    # 运行测试套件
    test_config_parsing
    test_directory_structure
    test_docker_compose_config
    test_network_functions
    test_file_operations
    test_logging_functions
    test_config_validation
    test_error_handling
    test_performance
    test_integration
    
    # 清理测试环境
    cleanup_test_env
    
    # 显示测试结果
    show_test_results
}

# 显示测试结果
show_test_results() {
    local success_rate=0
    if [ $TESTS_RUN -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                              测试结果摘要                                   ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n📊 ${YELLOW}测试统计${NC}"
    echo -e "执行测试: $TESTS_RUN"
    echo -e "通过测试: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "失败测试: ${RED}$TESTS_FAILED${NC}"
    echo -e "成功率: ${GREEN}$success_rate%${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n🎉 ${GREEN}所有单元测试通过！${NC}"
        return 0
    else
        echo -e "\n⚠️  ${RED}有 $TESTS_FAILED 个测试失败，请检查代码。${NC}"
        return 1
    fi
}

# 使用说明
show_usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help          显示帮助信息"
    echo "  -v, --verbose       详细输出"
    echo "  -c, --config        仅配置测试"
    echo "  -f, --files         仅文件操作测试"
    echo "  -n, --network       仅网络测试"
    echo "  -i, --integration   仅集成测试"
}

# 主函数
main() {
    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -c|--config)
            setup_test_env
            test_config_parsing
            test_config_validation
            cleanup_test_env
            show_test_results
            ;;
        -f|--files)
            setup_test_env
            test_directory_structure
            test_file_operations
            cleanup_test_env
            show_test_results
            ;;
        -n|--network)
            setup_test_env
            test_network_functions
            cleanup_test_env
            show_test_results
            ;;
        -i|--integration)
            setup_test_env
            test_integration
            cleanup_test_env
            show_test_results
            ;;
        *)
            run_all_tests
            ;;
    esac
}

# 捕获退出信号，确保清理
trap cleanup_test_env EXIT

# 执行主函数
main "$@"