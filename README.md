# NAS 终极自动化影音管理系统

一个基于"想看什么，点一下，然后就能在 Emby 里直接看"理念的全自动化家庭数字媒体中心。

## 🎯 核心特性

- **全自动化流水线**: 用户需求 → MoviePilot 调度 → 下载器执行 → 媒体库整理 → 微信通知
- **一站式数字生活中心**: 涵盖影视、音乐、漫画、电子书、有声书等全媒体类型
- **PT 生态深度集成**: 自动辅种、刷流、Cookie 同步等高级功能
- **极致用户体验**: Homepage 导航页 + 微信通知 + 多设备访问

## 🏗️ 系统架构

### 硬件架构
```
硬件层：i3-8100T CPU + 8-32GB DDR4 + SSD系统盘 + HDD数据盘
虚拟化层：Proxmox VE → 飞牛OS VM + Ubuntu Server VM
应用层：50+ Docker 容器服务
```

### 软件架构
- **核心自动化层**: MoviePilot, Emby, qBittorrent, Transmission
- **内容获取层**: CookieCloud, ChineseSubFinder, IYUU, Vertex
- **媒体库扩展层**: Komga, Audiobookshelf, Navidrome, Calibre
- **工具服务层**: Homepage, Watchtower, UptimeKuma, RSS服务

## 📁 目录结构

```
/opt/nas-data/
├── downloads/                    # 下载临时目录
├── media/                       # 媒体库根目录
├── config/                      # 配置文件目录
└── scripts/                     # 脚本目录
```

## 🚀 快速开始

### 前置要求
- Ubuntu 20.04+ 或 Debian 11+
- 8GB+ 内存
- 100GB+ 系统盘空间
- 4TB+ 数据盘

### 一键安装
```bash
# 下载并安装
curl -fsSL https://raw.githubusercontent.com/your-repo/nas-aio/main/install.sh | bash

# 或使用 Makefile
wget https://github.com/your-repo/nas-aio/archive/main.zip
unzip main.zip && cd nas-aio-main
make install
```

### 手动安装
```bash
git clone https://github.com/your-repo/nas-aio.git
cd nas-aio

# 使用 Makefile（推荐）
make install

# 或直接运行脚本
chmod +x install.sh
./install.sh
```

### 快速管理命令
```bash
# 查看帮助
make help

# 启动所有服务
make start

# 查看服务状态
make status

# 查看日志
make logs

# 运行测试
make test

# 创建备份
make backup
```

## 📋 服务清单

### 核心服务 (端口 8000-8099)
- MoviePilot: 8001 - 总调度中心
- Emby: 8096 - 媒体服务器
- qBittorrent: 8080 - 主力下载器
- CookieCloud: 8088 - Cookie同步

### 扩展服务 (端口 9000-9099)
- Transmission: 9091 - 保种下载器
- IYUU: 9780 - 自动辅种
- UptimeKuma: 9001 - 服务监控

### 专用服务 (端口 25000+)
- Komga: 25600 - 漫画服务器
- Audiobookshelf: 25378 - 有声书服务器
- Navidrome: 25533 - 音乐服务器

### 工具服务 (端口 3000-3099)
- Homepage: 3000 - 统一导航页
- Vertex: 3030 - PT刷流工具

## 🔧 配置指南

详细配置请参考 [部署文档](docs/deployment.md)

## 📊 监控指标

- CPU 使用率告警阈值: >80%
- 内存使用率告警阈值: >85%
- 磁盘空间告警阈值: >90%

## 🛠️ 故障排除

常见问题请参考 [故障排除指南](docs/troubleshooting.md)

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request

## ☎️ 支持

- 项目Wiki: [链接]
- QQ群: [群号]
- 微信群: [二维码]