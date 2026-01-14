#!/system/bin/mksh

# Android 焦点应用监控脚本
# 依赖：su, dumpsys, grep, sed, cut, date, 以及 HTTP 客户端（curl/wget/busybox/toybox）

CONFIG_FILE="./.config.txt"
LOG_FILE="./monitor.log"
PID_FILE="./monitor.pid"

# 日志函数
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp $1" >> "$LOG_FILE"
    echo "$1"
}

# 错误处理
error_exit() {
    log "ERROR: $1"
    exit 1
}

# 检查必要命令
for cmd in su dumpsys grep sed cut date; do
    command -v $cmd >/dev/null 2>&1 || error_exit "命令 $cmd 未找到"
done

# 检测可用的 HTTP 客户端
HTTP_CLIENT=""
HTTP_CLIENT_NAME=""
if command -v curl >/dev/null 2>&1; then
    HTTP_CLIENT="curl"
    HTTP_CLIENT_NAME="curl"
elif command -v wget >/dev/null 2>&1; then
    HTTP_CLIENT="wget"
    HTTP_CLIENT_NAME="wget"
elif command -v busybox >/dev/null 2>&1 && busybox | grep -q wget; then
    HTTP_CLIENT="busybox wget"
    HTTP_CLIENT_NAME="busybox wget"
elif command -v toybox >/dev/null 2>&1 && toybox wget 2>&1 | grep -q -v "Unknown command"; then
    HTTP_CLIENT="toybox wget"
    HTTP_CLIENT_NAME="toybox wget"
else
    error_exit "未找到可用的 HTTP 客户端 (curl, wget, busybox wget, toybox wget)"
fi
log "使用 HTTP 客户端: $HTTP_CLIENT_NAME"

# 检查配置文件
if [[ ! -f "$CONFIG_FILE" ]]; then
    error_exit "配置文件不存在: $CONFIG_FILE"
fi

# 读取配置（键值对格式）
# 示例行：api_base=http://127.0.0.1:11451/api/v1
# 移除可能的引号和尾随逗号
parse_config() {
    local key="$1"
    local line=$(grep -i "^[[:space:]]*$key=" "$CONFIG_FILE" | head -1)
    if [[ -n "$line" ]]; then
        echo "$line" | cut -d'=' -f2- | sed -e 's/^[" ]*//' -e 's/[" ,]*$//'
    else
        echo ""
    fi
}

API_BASE=$(parse_config "api_base")
TOKEN=$(parse_config "token")
DEVICE=$(parse_config "device")
INTERVAL=$(parse_config "interval_seconds")

# 默认值
: ${API_BASE:=http://127.0.0.1:11451/api/v1}
: ${TOKEN:=your_token}
: ${DEVICE:=phone}
: ${INTERVAL:=60}

log "启动监控脚本，设备: $DEVICE, 间隔: ${INTERVAL}秒, API: $API_BASE"

# 信号处理
trap 'log "接收到退出信号，停止监控"; exit 0' INT TERM

# HTTP POST 函数
http_post() {
    local json="$1"
    local url="$2"
    local response=""
    local status=0

    case $HTTP_CLIENT in
        curl)
            response=$(curl -s -X POST -H "Content-Type: application/json" -d "$json" --max-time 10 "$url" 2>&1)
            status=$?
            ;;
        wget)
            response=$(wget -qO- -T 10 --post-data="$json" --header="Content-Type: application/json" "$url" 2>&1)
            status=$?
            ;;
        "busybox wget")
            response=$(busybox wget -qO- -T 10 --post-data="$json" --header="Content-Type: application/json" "$url" 2>&1)
            status=$?
            ;;
        "toybox wget")
            response=$(toybox wget -qO- -T 10 --post-data="$json" --header="Content-Type: application/json" "$url" 2>&1)
            status=$?
            ;;
        *)
            error_exit "HTTP 客户端配置错误"
            ;;
    esac

    if [[ $status -eq 0 ]]; then
        log "HTTP 请求成功"
        echo "$response"
        return 0
    else
        log "HTTP 请求失败: $response"
        return 1
    fi
}

# 获取电量百分比
get_battery_level() {
    local level=$(su -c "dumpsys battery | grep level | awk '{print \$2}'" 2>/dev/null)
    if [[ -n "$level" && "$level" =~ ^[0-9]+$ ]]; then
        echo "$level"
    else
        echo "100"  # 默认值
    fi
}

# 获取正在播放的音乐名称（如果有）
get_music_name() {
    local music=$(su -c "dumpsys media_session | sed -n '/User Records:/,/Controller Records:/p' | grep -m 1 'metadata:' | sed 's/.*description=//' | cut -d',' -f1" 2>/dev/null)
    local artist=$(su -c "dumpsys media_session | sed -n '/User Records:/,/Controller Records:/p' | grep -m 1 'metadata:' | sed 's/.*description=//' | cut -d',' -f2" 2>/dev/null)
    if [[ -n "$music" && "$music" != "null" ]]; then
        if [[ -n "$artist" && "$artist" != "null" ]]; then
            echo "$music - $artist"
        else
            echo "$music"
        fi
    else
        echo ""
    fi
}

# 主循环
while true; do
    # 获取当前时间 (ISO 8601)
    TIME=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')

    # 获取顶层活动
    ACTIVITY_OUTPUT=$(su -c "dumpsys activity top | grep ACTIVITY 2>/dev/null")
    if [[ $? -ne 0 ]]; then
        log "WARN: dumpsys 命令失败"
        PACKAGE="unknown"
    else
        LAST_LINE=$(echo "$ACTIVITY_OUTPUT" | tail -1)
        # 提取包名，格式示例：ACTIVITY com.example/.MainActivity
        PACKAGE=$(echo "$LAST_LINE" | sed -n 's/.*ACTIVITY \([^/]*\)\/.*/\1/p')
        if [[ -z "$PACKAGE" ]]; then
            log "WARN: 无法从行中提取包名: $LAST_LINE"
            PACKAGE="unknown"
        fi
    fi

    # 获取电量和音乐信息
    CHARGE=$(get_battery_level)
    MUSIC=$(get_music_name)

    # 构造 JSON 负载
    if [[ -n "$MUSIC" ]]; then
        JSON="{\"token\":\"$TOKEN\",\"device\":\"$DEVICE\",\"application\":\"$PACKAGE\",\"time\":\"$TIME\",\"data\":{\"charge\":$CHARGE,\"music_name\":\"$MUSIC\"}}"
    else
        JSON="{\"token\":\"$TOKEN\",\"device\":\"$DEVICE\",\"application\":\"$PACKAGE\",\"time\":\"$TIME\",\"data\":{\"charge\":$CHARGE}}"
    fi

    # 发送 HTTP POST 请求
    max_retries=999
    retry=0
    success=false
    while [[ $retry -le $max_retries && $success == false ]]; do
        if http_post "$JSON" "${API_BASE}/admin/record"; then
            log "INFO: 发送成功，包名: $PACKAGE"
            success=true
        else
            log "WARN: 第 $((retry+1)) 次发送失败"
            retry=$((retry+1))
            if [[ $retry -le $max_retries ]]; then
                sleep 2
            fi
        fi
    done

    if [[ $success == false ]]; then
        log "ERROR: 发送失败，已达最大重试次数"
    fi

    # 等待间隔
    sleep "$INTERVAL"
done