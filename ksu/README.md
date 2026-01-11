# Android 焦点应用监控模块

这是一个 KernelSU 模块，用于在 Android 设备启动时运行监控脚本，定期获取顶层活动并上报到指定 API。

## 功能

- 监控当前前台应用（包名）
- 通过 HTTP POST 上报到配置的 API 端点
- 可配置上报间隔、设备标识、令牌等
- 自动重试机制（最多 999 次）
- 日志记录到模块目录下的 `monitor.log`

## 安装

1. 确保设备已安装 KernelSU。
2. 将本模块文件夹（或打包的 zip）放入 `/data/adb/modules/` 目录，或通过 KernelSU Manager 安装。
3. 重启设备或手动启用模块。

## 配置

编辑模块目录下的 `.config.txt` 文件：

```
api_base=http://127.0.0.1:11451/api/v1
token=your_token
device=phone
interval_seconds=60
```

- `api_base`: API 基础地址（无需包含 `/admin/record`）
- `token`: 认证令牌
- `device`: 设备标识
- `interval_seconds`: 上报间隔（秒）

## 文件说明

- `module.prop` – 模块元数据
- `service.sh` – 启动脚本（由 KernelSU 在启动时执行）
- `post-fs-data.sh` – 设置文件权限
- `monitor.sh` – 主监控脚本
- `.config.txt` – 配置文件
- `uninstall.sh` – 卸载时清理脚本

## 手动控制

- 启动监控：`/data/adb/modules/monitor_service/service.sh start`
- 停止监控：`/data/adb/modules/monitor_service/service.sh stop`
- 查看日志：`cat /data/adb/modules/monitor_service/monitor.log`

## 注意事项

- 需要 root 权限（su）
- 依赖 `dumpsys`、`grep`、`sed`、`cut`、`date` 等命令
- 需要可用的 HTTP 客户端（curl、wget、busybox wget、toybox wget 之一）
- 确保配置的 API 地址可访问

## 故障排除

如果监控未启动，检查：
1. 模块是否已启用（KernelSU Manager）
2. 日志文件是否有错误
3. 配置文件格式是否正确
4. 网络连接是否正常

## 许可证

自由使用，无担保。