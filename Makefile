# =============================================================================
# NAS 自动化系统 Makefile
# =============================================================================

.PHONY: help install start stop restart status logs clean test backup update

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
NC     := \033[0m # No Color

# 配置变量
COMPOSE_CORE := docker-compose.core.yml
COMPOSE_EXTEND := docker-compose.extend.yml
COMPOSE_MONITOR := docker-compose.monitoring.yml
ENV_FILE := .env

# 帮助信息
help: ## 显示可用的命令
	@echo "NAS 自动化影音管理系统"
	@echo "======================"
	@echo ""
	@echo "可用命令:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "示例:"
	@echo "  make install    # 安装整个系统"
	@echo "  make start      # 启动所有服务"  
	@echo "  make logs       # 查看服务日志"
	@echo "  make test       # 运行测试"

# 系统安装
install: ## 一键安装整个系统
	@echo "$(GREEN)[INSTALL]$(NC) 开始安装 NAS 自动化系统..."
	@chmod +x install.sh
	@./install.sh
	@echo "$(GREEN)[INSTALL]$(NC) 安装完成！"

# 快速安装（跳过系统更新）
install-quick: ## 快速安装（跳过系统更新）
	@echo "$(GREEN)[INSTALL]$(NC) 开始快速安装..."
	@chmod +x install.sh
	@./install.sh --quick
	@echo "$(GREEN)[INSTALL]$(NC) 快速安装完成！"

# 目录设置
setup-dirs: ## 创建目录结构
	@echo "$(GREEN)[SETUP]$(NC) 创建目录结构..."
	@chmod +x setup-directories.sh
	@sudo ./setup-directories.sh
	@echo "$(GREEN)[SETUP]$(NC) 目录创建完成！"

# 检查环境
check-env: ## 检查环境配置
	@echo "$(YELLOW)[CHECK]$(NC) 检查环境配置..."
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "$(RED)[ERROR]$(NC) 环境配置文件不存在，正在创建..."; \
		cp .env.template $(ENV_FILE); \
		echo "$(YELLOW)[WARN]$(NC) 请编辑 $(ENV_FILE) 文件配置系统参数"; \
	else \
		echo "$(GREEN)[OK]$(NC) 环境配置文件存在"; \
	fi
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "$(RED)[ERROR]$(NC) Docker 未安装"; \
		exit 1; \
	else \
		echo "$(GREEN)[OK]$(NC) Docker 已安装"; \
	fi
	@if ! command -v docker-compose >/dev/null 2>&1; then \
		echo "$(RED)[ERROR]$(NC) Docker Compose 未安装"; \
		exit 1; \
	else \
		echo "$(GREEN)[OK]$(NC) Docker Compose 已安装"; \
	fi

# 拉取镜像
pull: check-env ## 拉取 Docker 镜像
	@echo "$(GREEN)[PULL]$(NC) 拉取核心服务镜像..."
	@docker-compose -f $(COMPOSE_CORE) --env-file $(ENV_FILE) pull
	@echo "$(GREEN)[PULL]$(NC) 拉取扩展服务镜像..."
	@docker-compose -f $(COMPOSE_EXTEND) --env-file $(ENV_FILE) pull
	@echo "$(GREEN)[PULL]$(NC) 镜像拉取完成！"

# 启动服务
start: check-env ## 启动所有服务
	@echo "$(GREEN)[START]$(NC) 启动核心服务..."
	@docker-compose -f $(COMPOSE_CORE) --env-file $(ENV_FILE) up -d
	@echo "$(GREEN)[START]$(NC) 启动扩展服务..."
	@docker-compose -f $(COMPOSE_EXTEND) --env-file $(ENV_FILE) up -d
	@echo "$(GREEN)[START]$(NC) 所有服务启动完成！"
	@sleep 10
	@make status

# 启动核心服务
start-core: check-env ## 仅启动核心服务
	@echo "$(GREEN)[START]$(NC) 启动核心服务..."
	@docker-compose -f $(COMPOSE_CORE) --env-file $(ENV_FILE) up -d
	@echo "$(GREEN)[START]$(NC) 核心服务启动完成！"

# 启动扩展服务
start-extend: check-env ## 仅启动扩展服务
	@echo "$(GREEN)[START]$(NC) 启动扩展服务..."
	@docker-compose -f $(COMPOSE_EXTEND) --env-file $(ENV_FILE) up -d
	@echo "$(GREEN)[START]$(NC) 扩展服务启动完成！"

# 启动监控服务
start-monitor: check-env ## 启动监控服务
	@echo "$(GREEN)[START]$(NC) 启动监控服务..."
	@docker-compose -f $(COMPOSE_MONITOR) --env-file $(ENV_FILE) up -d
	@echo "$(GREEN)[START]$(NC) 监控服务启动完成！"

# 停止服务
stop: ## 停止所有服务
	@echo "$(YELLOW)[STOP]$(NC) 停止所有服务..."
	@docker-compose -f $(COMPOSE_CORE) --env-file $(ENV_FILE) down 2>/dev/null || true
	@docker-compose -f $(COMPOSE_EXTEND) --env-file $(ENV_FILE) down 2>/dev/null || true
	@docker-compose -f $(COMPOSE_MONITOR) --env-file $(ENV_FILE) down 2>/dev/null || true
	@echo "$(YELLOW)[STOP]$(NC) 所有服务已停止！"

# 重启服务
restart: ## 重启所有服务
	@echo "$(YELLOW)[RESTART]$(NC) 重启所有服务..."
	@make stop
	@sleep 5
	@make start
	@echo "$(GREEN)[RESTART]$(NC) 服务重启完成！"

# 查看状态
status: ## 查看服务状态
	@echo "$(BLUE)[STATUS]$(NC) 核心服务状态:"
	@docker-compose -f $(COMPOSE_CORE) --env-file $(ENV_FILE) ps 2>/dev/null || echo "核心服务未启动"
	@echo ""
	@echo "$(BLUE)[STATUS]$(NC) 扩展服务状态:"
	@docker-compose -f $(COMPOSE_EXTEND) --env-file $(ENV_FILE) ps 2>/dev/null || echo "扩展服务未启动"

# 查看日志
logs: ## 查看所有服务日志
	@echo "$(BLUE)[LOGS]$(NC) 查看服务日志 (Ctrl+C 退出)..."
	@docker-compose -f $(COMPOSE_CORE) --env-file $(ENV_FILE) logs -f --tail=100

# 查看特定服务日志
logs-%: ## 查看指定服务日志 (如: make logs-moviepilot)
	@echo "$(BLUE)[LOGS]$(NC) 查看 $* 服务日志..."
	@docker logs $* -f --tail=100

# 执行测试
test: ## 运行完整测试套件
	@echo "$(GREEN)[TEST]$(NC) 运行测试套件..."
	@chmod +x run-tests.sh
	@./run-tests.sh

# 快速测试
test-quick: ## 运行快速测试
	@echo "$(GREEN)[TEST]$(NC) 运行快速测试..."
	@chmod +x run-tests.sh
	@./run-tests.sh --quick

# 系统备份
backup: ## 创建系统备份
	@echo "$(GREEN)[BACKUP]$(NC) 创建系统备份..."
	@chmod +x scripts/backup.sh
	@./scripts/backup.sh
	@echo "$(GREEN)[BACKUP]$(NC) 备份完成！"

# 系统监控
monitor: ## 运行系统监控
	@echo "$(GREEN)[MONITOR]$(NC) 运行系统监控..."
	@chmod +x scripts/monitoring.sh
	@./scripts/monitoring.sh

# 更新系统
update: ## 更新所有服务
	@echo "$(GREEN)[UPDATE]$(NC) 更新所有服务..."
	@make pull
	@make restart
	@echo "$(GREEN)[UPDATE]$(NC) 更新完成！"

# 清理系统
clean: ## 清理无用的 Docker 资源
	@echo "$(YELLOW)[CLEAN]$(NC) 清理 Docker 资源..."
	@docker system prune -f
	@docker volume prune -f
	@echo "$(YELLOW)[CLEAN]$(NC) 清理完成！"

# 完全清理
clean-all: ## 完全清理系统（包括数据）
	@echo "$(RED)[WARNING]$(NC) 这将删除所有容器和数据，确认请输入 'yes':"
	@read -p "" confirm && [ "$$confirm" = "yes" ] || (echo "操作取消" && exit 1)
	@make stop
	@docker-compose -f $(COMPOSE_CORE) --env-file $(ENV_FILE) down -v --rmi all
	@docker-compose -f $(COMPOSE_EXTEND) --env-file $(ENV_FILE) down -v --rmi all
	@docker system prune -af --volumes
	@echo "$(RED)[CLEAN]$(NC) 完全清理完成！"

# 显示系统信息
info: ## 显示系统信息
	@echo "$(BLUE)[INFO]$(NC) 系统信息:"
	@echo "  操作系统: $$(lsb_release -d 2>/dev/null | cut -f2 || uname -s)"
	@echo "  Docker 版本: $$(docker --version 2>/dev/null || echo '未安装')"
	@echo "  Docker Compose 版本: $$(docker-compose --version 2>/dev/null || echo '未安装')"
	@echo "  CPU 核心数: $$(nproc)"
	@echo "  总内存: $$(free -h | grep Mem | awk '{print $$2}')"
	@echo "  磁盘空间: $$(df -h / | awk 'NR==2{print $$4}' | xargs echo '可用')"
	@echo ""
	@echo "$(BLUE)[INFO]$(NC) 服务访问地址:"
	@echo "  Homepage: http://$$(hostname -I | awk '{print $$1}'):3000"
	@echo "  MoviePilot: http://$$(hostname -I | awk '{print $$1}'):8001"
	@echo "  Emby: http://$$(hostname -I | awk '{print $$1}'):8096"
	@echo "  qBittorrent: http://$$(hostname -I | awk '{print $$1}'):8080"

# 配置向导
config: ## 配置向导
	@echo "$(GREEN)[CONFIG]$(NC) 配置向导..."
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "创建配置文件..."; \
		cp .env.template $(ENV_FILE); \
	fi
	@echo "当前配置文件: $(ENV_FILE)"
	@echo "请根据需要修改配置文件，然后运行 'make start' 启动系统"
	@echo ""
	@echo "重要配置项:"
	@grep -E "^(MOVIEPILOT_|QB_|TRANSMISSION_)" $(ENV_FILE) || true

# 健康检查
health: ## 系统健康检查
	@echo "$(GREEN)[HEALTH]$(NC) 执行系统健康检查..."
	@chmod +x tests/system-test.sh
	@./tests/system-test.sh --quick

# 显示端口使用情况
ports: ## 显示端口使用情况
	@echo "$(BLUE)[PORTS]$(NC) 端口使用情况:"
	@echo "服务端口:"
	@netstat -tuln 2>/dev/null | grep -E ":(3000|8001|8096|8080|9091|25600|25378|25533)" | sort -t: -k2 -n || echo "无服务端口监听"

# 生成配置
gen-config: ## 生成随机密码配置
	@echo "$(GREEN)[CONFIG]$(NC) 生成配置文件..."
	@cp .env.template .env.new
	@sed -i "s/your_api_token_here/$$(openssl rand -hex 32)/" .env.new
	@sed -i "s/your_emby_api_key_here/$$(openssl rand -hex 16)/" .env.new
	@sed -i "s/adminpass/$$(openssl rand -base64 12)/" .env.new
	@sed -i "s/password123/$$(openssl rand -base64 12)/" .env.new
	@echo "配置文件已生成: .env.new"
	@echo "请检查配置后重命名为 .env 使用"

# 开发模式
dev: ## 开发模式启动
	@echo "$(YELLOW)[DEV]$(NC) 开发模式启动..."
	@make start-core
	@echo "开发模式启动完成，仅启动核心服务"

# 生产模式
prod: ## 生产模式启动
	@echo "$(GREEN)[PROD]$(NC) 生产模式启动..."
	@make start
	@make start-monitor
	@echo "生产模式启动完成，所有服务已启动"