# NAS 自动化系统部署指南

## 📋 目录
- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [详细安装步骤](#详细安装步骤)
- [服务配置](#服务配置)
- [故障排除](#故障排除)
- [维护指南](#维护指南)

## 🔧 系统要求

### 最低配置
- **CPU**: 4核心 (推荐 Intel i3-8100T 或同等性能)
- **内存**: 8GB DDR4 (推荐 16GB+)
- **存储**: 
  - 系统盘: 128GB SSD
  - 数据盘: 4TB+ HDD
- **网络**: 千兆网卡
- **系统**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+

### 推荐配置
- **CPU**: Intel i3-8100T (35W TDP)
- **内存**: 32GB DDR4 ECC
- **存储**:
  - 系统盘: 256GB NVMe SSD
  - 数据盘: 多块 4TB+ HDD 组成存储池
- **主板**: 支持多个 SATA 接口的服务器主板

## 🚀 快速开始

### 一键安装
```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/your-repo/nas-aio/main/install.sh -o install.sh

# 设置执行权限
chmod +x install.sh

# 运行安装
./install.sh
```

### 安装完成后访问
- **Homepage 导航页**: http://your-server-ip:3000
- **MoviePilot 管理**: http://your-server-ip:8001
- **Emby 媒体服务器**: http://your-server-ip:8096

## 📖 详细安装步骤

### 1. 环境准备

#### 更新系统
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
```

#### 安装基础工具
```bash
# Ubuntu/Debian
sudo apt install -y curl wget git unzip htop iotop nethogs tree vim nano

# CentOS/RHEL  
sudo yum install -y curl wget git unzip htop iotop nethogs tree vim nano
```

### 2. 克隆项目
```bash
git clone https://github.com/your-repo/nas-aio.git
cd nas-aio
```

### 3. 创建目录结构
```bash
# 运行目录设置脚本
chmod +x setup-directories.sh
sudo ./setup-directories.sh
```

### 4. 安装 Docker 和 Docker Compose

#### 安装 Docker
```bash
# 使用官方安装脚本
curl -fsSL https://get.docker.com | sh

# 添加用户到 docker 组
sudo usermod -aG docker $USER

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker
```

#### 安装 Docker Compose
```bash
# 下载最新版本
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 设置执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 创建软链接
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

### 5. 配置环境变量
```bash
# 复制环境变量模板
cp .env.template .env

# 编辑配置文件
nano .env
```

#### 重要配置项说明
```bash
# 用户ID和组ID（使用 id 命令查看）
PUID=1000
PGID=1000

# 时区设置
TZ=Asia/Shanghai

# 路径配置
DATA_PATH=/opt/nas-data
DOWNLOAD_PATH=/opt/nas-data/downloads
MEDIA_PATH=/opt/nas-data/media
CONFIG_PATH=/opt/nas-data/config

# MoviePilot 管理员账号
MOVIEPILOT_SUPERUSER=admin
MOVIEPILOT_SUPERUSER_PASSWORD=your_secure_password

# qBittorrent 账号
QB_USERNAME=admin
QB_WEBUI_PASSWORD=your_secure_password
```

### 6. 启动服务

#### 启动核心服务
```bash
# 拉取镜像
docker-compose -f docker-compose.core.yml pull

# 启动服务
docker-compose -f docker-compose.core.yml up -d

# 检查服务状态
docker-compose -f docker-compose.core.yml ps
```

#### 启动扩展服务
```bash
# 拉取镜像
docker-compose -f docker-compose.extend.yml pull

# 启动服务
docker-compose -f docker-compose.extend.yml up -d
```

#### 启动监控服务（可选）
```bash
# 启动监控服务
docker-compose -f docker-compose.monitoring.yml up -d
```

## ⚙️ 服务配置

### MoviePilot 配置

1. 访问 http://your-server-ip:8001
2. 使用配置的管理员账号登录
3. 配置基本设置：
   - 媒体库路径
   - 下载器连接
   - 索引器设置
   - 通知配置

### Emby 配置

1. 访问 http://your-server-ip:8096
2. 完成初始设置向导
3. 添加媒体库：
   - 电影库: `/media/movies`
   - 电视剧库: `/media/tv`
   - 音乐库: `/media/music`

### qBittorrent 配置

1. 访问 http://your-server-ip:8080
2. 登录账号（见 .env 配置）
3. 设置下载路径：
   - 默认保存路径: `/downloads/complete`
   - 未完成下载路径: `/downloads/incomplete`

### Homepage 配置

1. 访问 http://your-server-ip:3000
2. 配置文件位置: `/opt/nas-data/config/homepage/`
3. 根据需要修改服务链接和显示内容

## 🔍 服务状态检查

### 查看所有容器状态
```bash
docker ps
```

### 查看特定服务日志
```bash
# 查看 MoviePilot 日志
docker logs moviepilot -f

# 查看 Emby 日志
docker logs emby -f

# 查看所有核心服务日志
docker-compose -f docker-compose.core.yml logs -f
```

### 重启服务
```bash
# 重启单个服务
docker restart moviepilot

# 重启核心服务
docker-compose -f docker-compose.core.yml restart

# 重启所有服务
./scripts/manage-services.sh restart
```

## 🛡️ 安全配置

### 防火墙设置
```bash
# Ubuntu/Debian
sudo ufw enable
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 3000/tcp  # Homepage
sudo ufw allow 8001/tcp  # MoviePilot
sudo ufw allow 8096/tcp  # Emby

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=8001/tcp
sudo firewall-cmd --permanent --add-port=8096/tcp
sudo firewall-cmd --reload
```

### SSL/HTTPS 配置（可选）

使用 Nginx 反向代理配置 HTTPS：

```nginx
# /etc/nginx/sites-available/nas
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /moviepilot/ {
        proxy_pass http://localhost:8001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 📊 监控配置

### Prometheus + Grafana 监控

1. 启动监控服务：
```bash
docker-compose -f docker-compose.monitoring.yml up -d
```

2. 访问监控面板：
   - Grafana: http://your-server-ip:3001 (admin/admin123)
   - Prometheus: http://your-server-ip:9090
   - UptimeKuma: http://your-server-ip:9001

3. 配置 Grafana 仪表板：
   - 导入预配置的仪表板
   - 设置告警规则

### 日志管理

查看系统日志：
```bash
# 查看安装日志
tail -f /tmp/nas-install.log

# 查看监控日志
tail -f /opt/nas-data/logs/monitoring.log

# 查看告警日志
tail -f /opt/nas-data/logs/alerts.log
```

## 🔄 更新升级

### 更新单个服务
```bash
# 更新 MoviePilot
docker-compose -f docker-compose.core.yml pull moviepilot
docker-compose -f docker-compose.core.yml up -d moviepilot
```

### 批量更新服务
```bash
# 使用管理脚本更新所有服务
./scripts/manage-services.sh update
```

### 系统升级
```bash
# 备份当前配置
./scripts/backup.sh

# 拉取最新代码
git pull origin main

# 重新部署
./install.sh
```

## 📁 目录权限设置

确保目录权限正确：
```bash
sudo chown -R $(id -u):$(id -g) /opt/nas-data
sudo chmod -R 755 /opt/nas-data
sudo chmod -R 777 /opt/nas-data/downloads
```

## 🎯 性能优化

### Docker 优化
```bash
# 清理无用镜像和容器
docker system prune -af

# 设置 Docker 日志限制
# 编辑 /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### 系统优化
```bash
# 调整 swappiness
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# 优化网络参数
echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' | sudo tee -a /etc/sysctl.conf

# 应用设置
sudo sysctl -p
```

## 📞 支持和帮助

### 常用命令速查
```bash
# 查看服务状态
./scripts/manage-services.sh status

# 查看服务日志
./scripts/manage-services.sh logs [service_name]

# 备份系统
./scripts/backup.sh

# 系统监控
./scripts/monitoring.sh

# 重启所有服务
./scripts/manage-services.sh restart
```

### 获取帮助
- 项目 Wiki: [链接]
- GitHub Issues: [链接]
- QQ 群: [群号]
- 微信群: [二维码]

### 问题反馈
遇到问题时，请提供以下信息：
1. 系统版本: `lsb_release -a`
2. Docker 版本: `docker --version`
3. 服务状态: `docker ps`
4. 错误日志: `docker logs [container_name]`