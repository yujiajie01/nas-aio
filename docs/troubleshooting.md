# NAS 自动化系统故障排除指南

## 📋 目录
- [常见问题诊断](#常见问题诊断)
- [服务故障排除](#服务故障排除)
- [网络问题解决](#网络问题解决)
- [存储问题处理](#存储问题处理)
- [性能问题优化](#性能问题优化)
- [日志分析](#日志分析)

## 🔍 常见问题诊断

### 系统健康检查脚本
```bash
#!/bin/bash
# 快速系统健康检查

echo "=== NAS 系统健康检查 ==="
echo "检查时间: $(date)"
echo

# 检查系统资源
echo "1. 系统资源使用情况:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')% 使用"
echo "内存: $(free | grep Mem | awk '{printf("%.1f%%\n", $3/$2 * 100.0)}')"
echo "磁盘: $(df -h / | awk 'NR==2{printf "%s\n", $5}')"
echo

# 检查 Docker 服务
echo "2. Docker 服务状态:"
if systemctl is-active --quiet docker; then
    echo "✅ Docker 服务运行正常"
else
    echo "❌ Docker 服务异常"
fi
echo

# 检查容器状态
echo "3. 重要容器状态:"
important_containers=("moviepilot" "emby" "qbittorrent" "transmission" "homepage")
for container in "${important_containers[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
        echo "✅ $container 运行正常"
    else
        echo "❌ $container 未运行"
    fi
done
echo

# 检查端口监听
echo "4. 关键端口状态:"
ports=("3000:Homepage" "8001:MoviePilot" "8096:Emby" "8080:qBittorrent")
for port_info in "${ports[@]}"; do
    port="${port_info%%:*}"
    name="${port_info##*:}"
    if netstat -tuln | grep -q ":${port} "; then
        echo "✅ $name (端口 $port) 监听正常"
    else
        echo "❌ $name (端口 $port) 未监听"
    fi
done
echo

# 检查磁盘空间
echo "5. 存储空间状态:"
if [ -d "/opt/nas-data" ]; then
    echo "数据目录: $(du -sh /opt/nas-data 2>/dev/null | cut -f1)"
    echo "下载目录: $(du -sh /opt/nas-data/downloads 2>/dev/null | cut -f1)"
    echo "媒体目录: $(du -sh /opt/nas-data/media 2>/dev/null | cut -f1)"
else
    echo "❌ 数据目录不存在"
fi

echo "=== 健康检查完成 ==="
```

### 快速修复脚本
```bash
#!/bin/bash
# 常见问题快速修复

echo "=== NAS 系统快速修复 ==="

# 重启异常容器
echo "1. 重启异常容器..."
failed_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}")
if [ -n "$failed_containers" ]; then
    echo "$failed_containers" | while read -r container; do
        echo "重启容器: $container"
        docker restart "$container"
    done
else
    echo "✅ 所有容器运行正常"
fi

# 清理系统资源
echo "2. 清理系统资源..."
docker system prune -f --volumes
echo "✅ Docker 清理完成"

# 修复权限问题
echo "3. 修复目录权限..."
if [ -d "/opt/nas-data" ]; then
    sudo chown -R $(id -u):$(id -g) /opt/nas-data
    sudo chmod -R 755 /opt/nas-data
    sudo chmod -R 777 /opt/nas-data/downloads
    echo "✅ 权限修复完成"
fi

echo "=== 快速修复完成 ==="
```

## 🛠️ 服务故障排除

### MoviePilot 问题

#### 无法访问 Web 界面
**现象**: 浏览器显示"无法连接"或超时

**诊断步骤**:
```bash
# 1. 检查容器状态
docker ps | grep moviepilot

# 2. 查看容器日志
docker logs moviepilot --tail 50

# 3. 检查端口监听
netstat -tlnp | grep 8001

# 4. 检查防火墙
sudo ufw status | grep 8001
```

**解决方案**:
```bash
# 重启容器
docker restart moviepilot

# 如果仍有问题，重新创建容器
docker-compose -f docker-compose.core.yml down moviepilot
docker-compose -f docker-compose.core.yml up -d moviepilot
```

#### 下载器连接失败
**现象**: MoviePilot 无法连接到 qBittorrent 或 Transmission

**诊断步骤**:
```bash
# 检查下载器容器状态
docker ps | grep -E "(qbittorrent|transmission)"

# 测试网络连通性
docker exec moviepilot ping qbittorrent
docker exec moviepilot curl -I http://qbittorrent:8080
```

**解决方案**:
1. 检查 .env 文件中的下载器配置
2. 确认下载器用户名密码正确
3. 重启相关容器

#### 媒体库同步异常
**现象**: 下载完成后文件未自动整理到媒体库

**诊断步骤**:
```bash
# 检查路径映射
docker inspect moviepilot | grep -A 10 "Mounts"

# 检查文件权限
ls -la /opt/nas-data/downloads/complete/
ls -la /opt/nas-data/media/
```

**解决方案**:
```bash
# 修复权限
sudo chown -R $(id -u):$(id -g) /opt/nas-data
sudo chmod -R 755 /opt/nas-data/media

# 手动触发媒体库整理
# 在 MoviePilot Web 界面进行手动整理
```

### Emby 问题

#### 无法扫描媒体库
**现象**: 新添加的文件不在 Emby 中显示

**诊断步骤**:
```bash
# 检查媒体目录挂载
docker exec emby ls -la /media/

# 检查文件权限
docker exec emby ls -la /media/movies/
```

**解决方案**:
```bash
# 手动刷新媒体库
# 在 Emby Web 界面: 设置 → 媒体库 → 扫描媒体库

# 或通过 API 刷新
curl -X POST "http://localhost:8096/emby/Library/Refresh"
```

#### 转码失败
**现象**: 视频播放时出现转码错误

**诊断步骤**:
```bash
# 查看 Emby 日志
docker logs emby | grep -i "transcode\|ffmpeg"

# 检查硬件加速设备
docker exec emby ls -la /dev/dri/
```

**解决方案**:
1. 禁用硬件加速测试
2. 检查视频文件是否损坏
3. 调整转码设置

### qBittorrent 问题

#### 下载速度慢
**现象**: 下载速度明显低于带宽

**诊断步骤**:
```bash
# 检查连接数设置
# Web 界面: 工具 → 选项 → 连接

# 检查端口是否开放
netstat -tlnp | grep 6881
```

**解决方案**:
1. 调整全局最大连接数
2. 增加每个种子的连接数
3. 检查 ISP 是否限制 P2P 流量

#### 无法连接 Tracker
**现象**: 种子显示"未连接到 Tracker"

**解决方案**:
```bash
# 更新 Tracker 列表
# 在 qBittorrent 中右键种子 → 编辑 Tracker

# 检查 DNS 解析
docker exec qbittorrent nslookup tracker.example.com
```

## 🌐 网络问题解决

### Docker 网络问题

#### 容器间无法通信
**诊断步骤**:
```bash
# 检查 Docker 网络
docker network ls
docker network inspect nas-network

# 测试容器间连通性
docker exec moviepilot ping emby
docker exec moviepilot curl -I http://qbittorrent:8080
```

**解决方案**:
```bash
# 重新创建网络
docker network rm nas-network
docker network create --driver bridge --subnet=172.20.0.0/16 nas-network

# 重启所有服务
docker-compose -f docker-compose.core.yml down
docker-compose -f docker-compose.core.yml up -d
```

#### 端口冲突
**现象**: 容器启动失败，提示端口被占用

**诊断步骤**:
```bash
# 查找占用端口的进程
sudo netstat -tlnp | grep :8080
sudo lsof -i :8080
```

**解决方案**:
```bash
# 终止占用进程
sudo kill -9 <PID>

# 或修改 docker-compose.yml 中的端口映射
ports:
  - "8081:8080"  # 改用其他端口
```

### 防火墙配置

#### 服务无法外部访问
**解决方案**:
```bash
# Ubuntu/Debian
sudo ufw allow 3000/tcp
sudo ufw allow 8001/tcp
sudo ufw allow 8096/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=8001/tcp
sudo firewall-cmd --permanent --add-port=8096/tcp
sudo firewall-cmd --reload
```

## 💾 存储问题处理

### 磁盘空间不足

#### 清理下载目录
```bash
# 清理未完成的下载
find /opt/nas-data/downloads/incomplete -name "*.!qB" -mtime +7 -delete

# 清理完成的下载（保留种子）
# 注意：确保已移动到媒体库的文件可以安全删除
```

#### 清理 Docker 数据
```bash
# 清理无用镜像
docker image prune -f

# 清理无用容器
docker container prune -f

# 清理无用卷
docker volume prune -f

# 清理构建缓存
docker builder prune -f
```

### 权限问题

#### 文件权限错误
```bash
# 批量修复权限
sudo chown -R $(id -u):$(id -g) /opt/nas-data
find /opt/nas-data -type d -exec chmod 755 {} \;
find /opt/nas-data -type f -exec chmod 644 {} \;

# 特殊目录权限
chmod 777 /opt/nas-data/downloads
chmod 755 /opt/nas-data/media
```

## 📈 性能问题优化

### 系统性能监控
```bash
# CPU 使用率监控
top -b -n 1 | grep "Cpu(s)"

# 内存使用监控
free -h

# 磁盘 IO 监控
iostat -x 1 5

# 网络流量监控
iftop -t -s 10
```

### Docker 性能优化

#### 资源限制配置
```yaml
# docker-compose.yml 中添加资源限制
services:
  moviepilot:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

#### 日志大小限制
```json
// /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

## 📊 日志分析

### 重要日志位置
```bash
# 系统日志
/var/log/syslog
/var/log/messages

# Docker 日志
/var/lib/docker/containers/*/

# 容器日志
docker logs <container_name>

# 应用日志
/opt/nas-data/logs/
```

### 日志分析工具
```bash
# 实时查看日志
tail -f /opt/nas-data/logs/monitoring.log

# 过滤错误日志
grep -i error /opt/nas-data/logs/*.log

# 统计日志级别
awk '{print $3}' /opt/nas-data/logs/monitoring.log | sort | uniq -c
```

### 常见错误模式

#### 权限错误
```
Permission denied (os error 13)
Operation not permitted
```
解决：检查文件权限和用户映射

#### 网络错误
```
Connection refused
Connection timeout
Name or service not known
```
解决：检查网络配置和 DNS 解析

#### 存储错误
```
No space left on device
Input/output error
```
解决：清理磁盘空间或检查磁盘健康

## 🚨 紧急恢复程序

### 系统完全不响应
```bash
# 1. 停止所有容器
docker stop $(docker ps -q)

# 2. 重启 Docker 服务
sudo systemctl restart docker

# 3. 检查系统资源
df -h
free -h
top

# 4. 重新启动核心服务
docker-compose -f docker-compose.core.yml up -d
```

### 配置文件损坏
```bash
# 1. 从备份恢复
cd /opt/nas-data/backup
tar -xzf latest_backup.tar.gz

# 2. 如果没有备份，重新生成配置
cp .env.template .env
# 手动编辑配置文件

# 3. 重新部署
./install.sh
```

### 数据丢失恢复
```bash
# 1. 立即停止所有写操作
docker-compose down

# 2. 使用数据恢复工具
sudo apt install testdisk
sudo testdisk

# 3. 从备份恢复
# 根据备份策略恢复数据
```

## 📞 获取更多帮助

### 诊断信息收集
```bash
# 生成系统诊断报告
./scripts/system-diagnosis.sh > diagnosis_report.txt

# 报告包含:
# - 系统信息
# - 容器状态
# - 网络配置  
# - 日志摘要
# - 配置文件状态
```

### 技术支持渠道
- GitHub Issues: 详细的问题报告
- 社区论坛: 经验分享和讨论
- QQ/微信群: 实时交流
- 邮件支持: 紧急问题联系

记住：遇到问题时，详细的日志信息和错误描述对解决问题非常重要！