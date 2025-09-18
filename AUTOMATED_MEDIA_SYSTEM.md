# 自动化追剧系统配置指南

## 系统概述

本系统基于 Radarr、Sonarr、Prowlarr 和 qBittorrent 构建，实现电影和电视剧的全自动化管理。系统能够自动搜索、下载、整理媒体文件，并与媒体服务器集成。

## 目录结构

```
/opt/nas-data/
├── media/
│   ├── Downloads/      # 下载目录
│   ├── Movies/         # Radarr整理后的电影目录
│   └── TV-Shows/       # Sonarr整理后的电视剧目录
└── config/
    ├── radarr/         # Radarr配置目录
    ├── sonarr/         # Sonarr配置目录
    ├── prowlarr/       # Prowlarr配置目录
    └── qbittorrent/    # qBittorrent配置目录
```

## 服务访问地址

| 服务        | 地址                  | 端口 | 默认账号密码       |
| ----------- | --------------------- | ---- | ------------------ |
| Radarr      | http://localhost:7878 | 7878 | 无(首次访问需设置) |
| Sonarr      | http://localhost:8989 | 8989 | 无(首次访问需设置) |
| Prowlarr    | http://localhost:9696 | 9696 | 无(首次访问需设置) |
| qBittorrent | http://localhost:8080 | 8080 | admin/adminadmin   |

## 启动服务

```bash
# 进入项目目录
cd /path/to/nas-aio

# 启动自动化追剧服务
docker-compose -f docker-compose.media.yml up -d
```

## 服务配置详解

### 1. qBittorrent 配置

#### 基础设置

1. 访问 http://localhost:8080
2. 使用默认账号密码登录: `admin` / `adminadmin`
3. 进入 `工具` → `选项`
4. 在 `下载` 选项卡中设置:
   - 保存路径: `/downloads`
   - 临时文件路径: `/downloads/incomplete`
   - 启用临时文件夹: 是
   - 在文件名末尾添加 .!qBittorrent 扩展名: 是

#### 连接设置

1. 在 `连接` 选项卡中设置:
   - 监听端口: 6881
   - 启用 UPnP: 否

#### BitTorrent 设置

1. 在 `BitTorrent` 选项卡中设置:
   - 最大连接数: 200
   - 每个 Torrent 最大连接数: 50
   - 全局最大上传数: 50
   - 每个 Torrent 最大上传数: 10

### 2. Prowlarr 配置

#### 添加索引器

1. 访问 http://localhost:9696
2. 进入 `索引器` → `添加索引器`
3. 选择需要的索引器类型(如: Torrent, Usenet 等)
4. 填写索引器信息:
   - 名称: 自定义
   - 启用: 是
   - URL: 索引器地址
   - API 密钥: 如有需要填写

#### 添加应用程序

1. 进入 `设置` → `应用程序`
2. 点击 `+` 添加应用程序
3. 选择 `Radarr` 或 `Sonarr`
4. 填写信息:
   - 名称: Radarr/Sonarr
   - 同步级别: 完全同步
   - Prowlarr 服务器: http://prowlarr:9696
   - Radarr/Sonarr 服务器: http://radarr:7878 或 http://sonarr:8989
   - API 密钥: 在 Radarr/Sonarr 中获取

### 3. Radarr 配置

#### 媒体管理设置

1. 访问 http://localhost:7878
2. 进入 `设置` → `媒体管理`
3. 设置根目录:
   - 添加根目录: `/movies`
4. 设置电影命名:
   - 标准电影格式: `{Movie Title} ({Release Year})/{Movie Title} ({Release Year}) {Quality Full}`

#### 下载客户端设置

1. 进入 `设置` → `下载客户端`
2. 点击 `+` 添加下载客户端
3. 选择 `qBittorrent`
4. 填写信息:
   - 名称: qBittorrent
   - 启用: 是
   - 主机: qbittorrent
   - 端口: 8080
   - 用户名: admin
   - 密码: adminadmin
   - 分类: radarr

#### 远程路径映射(如需要)

1. 在下载客户端设置中找到 `远程路径映射`
2. 添加映射:
   - 主机: qbittorrent
   - 本地路径: /opt/nas-data/media/Downloads
   - 远程路径: /downloads

### 4. Sonarr 配置

#### 媒体管理设置

1. 访问 http://localhost:8989
2. 进入 `设置` → `媒体管理`
3. 设置根目录:
   - 添加根目录: `/tv`
4. 设置电视剧命名:
   - 标准剧集格式: `{Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Full}`

#### 下载客户端设置

1. 进入 `设置` → `下载客户端`
2. 点击 `+` 添加下载客户端
3. 选择 `qBittorrent`
4. 填写信息:
   - 名称: qBittorrent
   - 启用: 是
   - 主机: qbittorrent
   - 端口: 8080
   - 用户名: admin
   - 密码: adminadmin
   - 分类: sonarr

#### 远程路径映射(如需要)

1. 在下载客户端设置中找到 `远程路径映射`
2. 添加映射:
   - 主机: qbittorrent
   - 本地路径: /opt/nas-data/media/Downloads
   - 远程路径: /downloads

## 使用流程

### 添加电影

1. 在 Radarr 中搜索电影
2. 点击 `添加电影`
3. 选择质量配置文件
4. Radarr 会自动通过 Prowlarr 搜索资源
5. 找到合适资源后发送给 qBittorrent 下载
6. 下载完成后自动整理到 `/movies` 目录

### 添加电视剧

1. 在 Sonarr 中搜索电视剧
2. 点击 `添加系列`
3. 选择监控方式(所有剧集、最新季等)
4. 选择质量配置文件
5. Sonarr 会自动通过 Prowlarr 搜索资源
6. 找到合适资源后发送给 qBittorrent 下载
7. 下载完成后自动整理到 `/tv` 目录

## 高级配置

### 质量配置

1. 在 Radarr/Sonarr 中进入 `设置` → `质量配置文件`
2. 创建或编辑质量配置文件
3. 设置优先级和允许的质量

### 通知配置

1. 在 Radarr/Sonarr 中进入 `设置` → `连接`
2. 添加通知方式(如: Telegram, Discord, Email 等)
3. 配置通知触发条件

### 自动升级

1. 在 Radarr/Sonarr 中进入 `设置` → `媒体管理`
2. 启用 `允许升级`
3. 系统会自动搜索更高质量的版本进行替换

## 故障排除

### 服务无法启动

1. 检查端口是否被占用
2. 检查目录权限
3. 查看容器日志: `docker-compose -f docker-compose.media.yml logs`

### 下载任务不执行

1. 检查 Prowlarr 索引器状态
2. 检查 qBittorrent 连接状态
3. 检查 Radarr/Sonarr 下载客户端配置

### 文件整理失败

1. 检查目录权限
2. 检查远程路径映射配置
3. 检查磁盘空间

## 维护管理

### 备份配置

```bash
# 备份配置目录
tar -czf radarr-backup-$(date +%Y%m%d).tar.gz /opt/nas-data/config/radarr
tar -czf sonarr-backup-$(date +%Y%m%d).tar.gz /opt/nas-data/config/sonarr
tar -czf prowlarr-backup-$(date +%Y%m%d).tar.gz /opt/nas-data/config/prowlarr
tar -czf qbittorrent-backup-$(date +%Y%m%d).tar.gz /opt/nas-data/config/qbittorrent
```

### 更新服务

```bash
# 拉取最新镜像
docker-compose -f docker-compose.media.yml pull

# 重启服务
docker-compose -f docker-compose.media.yml up -d
```

### 清理资源

```bash
# 清理无用的Docker资源
docker system prune -af
```
