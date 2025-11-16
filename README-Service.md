# CLI Proxy API 服务管理

## 服务状态

服务运行在端口 8317 上，提供 OpenAI/Claude/Gemini 兼容的API接口。

## 管理脚本

### 基本操作

```bash
# 查看服务状态
./manage-service.sh status

# 启动服务
./manage-service.sh start

# 停止服务
./manage-service.sh stop

# 重启服务
./manage-service.sh restart

# 查看最近的日志
./manage-service.sh logs
```

### 自启动设置

#### 方法1: 使用 cron (@reboot) - 推荐

这是最简单的方法，不需要root权限：

```bash
# 编辑 crontab
crontab -e

# 添加以下行
@reboot /home/yanwujin/CLIProxyAPI/auto-start.sh
```

保存后，系统重启时会自动启动服务。

#### 方法2: 使用 systemd 服务 (需要root权限)

**注意**: systemd服务已创建并启用，但由于`go run`的特殊性，建议使用方法1（cron）或手动管理脚本。

如果您有sudo权限，可以使用systemd服务：

```bash
# 创建服务文件 (需要sudo)
sudo tee /etc/systemd/system/cli-proxy-api.service > /dev/null << 'EOF'
[Unit]
Description=CLI Proxy API Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=yanwujin
WorkingDirectory=/home/yanwujin/CLIProxyAPI
ExecStart=/snap/bin/go run ./cmd/server --config config.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cli-proxy-api

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/home/yanwujin/.cli-proxy-api
ProtectHome=no

# Environment
Environment=PATH=/snap/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd配置
sudo systemctl daemon-reload

# 启用并启动服务
sudo systemctl enable cli-proxy-api.service
sudo systemctl start cli-proxy-api.service

# 查看状态
sudo systemctl status cli-proxy-api.service

# 查看日志
sudo journalctl -u cli-proxy-api.service -f
```

## 日志文件

- `logs/main.log`: 主要的应用程序日志
- `logs/service.log`: 服务启动相关日志
- `logs/auto-start.log`: 自启动脚本日志

## API 测试

```bash
# 测试模型列表
curl -X GET "http://localhost:8317/v1/models" \
  -H "Authorization: Bearer sk-moxi0306"

# 测试聊天完成 (使用配置文件中的API密钥)
curl -X POST "http://localhost:8317/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-moxi0306" \
  -d '{
    "model": "gpt-5",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ]
  }'
```

## 开发模式

如果您需要频繁修改代码，可以直接使用：

```bash
# 直接运行 (不需要编译)
go run ./cmd/server --config config.yaml

# 或者使用管理脚本
./manage-service.sh stop  # 停止后台服务
go run ./cmd/server --config config.yaml  # 前台运行进行调试
```

## 故障排除

1. **端口被占用**: 检查是否有其他进程使用8317端口
   ```bash
   ss -tlnp | grep 8317
   lsof -i :8317
   ```

2. **服务无法启动**: 检查日志文件
   ```bash
   tail -50 logs/main.log
   tail -20 logs/service.log
   ```

3. **权限问题**: 确保用户有权访问认证目录
   ```bash
   ls -la ~/.cli-proxy-api/
   ```

