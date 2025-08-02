#!/bin/bash

# Next.js 项目自动构建与部署脚本
# 用法: ./deploy.sh [选项]

set -e  # 遇到错误时退出

# 默认配置
PROJECT_DIR=""
PROJECT_NAME=""
BUILD_COMMAND=""
REMOTE_HOST=""
REMOTE_IMAGE_DIR=""
REMOTE_COMPOSE_DIR=""
PACKAGE_MANAGER=""
LOG_DIR=""
CONFIG_FILE=""
SKIP_INSTALL=false

# 全局变量
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
IMAGE_NAME=""
IMAGE_TAG=""
TEMP_DIR="/tmp/nextjs-deploy-$TIMESTAMP"
IMAGE_FILE=""
LOG_FILE=""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    local message="${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo -e "$message"
    [[ -n "$LOG_FILE" ]] && echo -e "$(date +'%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE" || true
}

log_info() {
    local message="${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
    echo -e "$message"
    [[ -n "$LOG_FILE" ]] && echo -e "$(date +'%Y-%m-%d %H:%M:%S') INFO: $1" >> "$LOG_FILE" || true
}

log_warn() {
    local message="${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
    echo -e "$message"
    [[ -n "$LOG_FILE" ]] && echo -e "$(date +'%Y-%m-%d %H:%M:%S') WARN: $1" >> "$LOG_FILE" || true
}

log_error() {
    local message="${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    echo -e "$message"
    [[ -n "$LOG_FILE" ]] && echo -e "$(date +'%Y-%m-%d %H:%M:%S') ERROR: $1" >> "$LOG_FILE" || true
}

# 显示帮助信息
show_help() {
    cat << EOF
Next.js 项目自动构建与部署脚本

USAGE:
    ./deploy.sh [OPTIONS]

OPTIONS:
    -p, --project-dir DIR       项目目录路径
    -n, --project-name NAME     项目名称（用于镜像命名）
    -c, --build-command CMD     构建命令 (如: "yarn build")
    -h, --remote-host HOST      远程服务器地址 (user@host)
    -i, --image-dir DIR         远程服务器镜像目录
    -d, --compose-dir DIR       远程服务器 Docker Compose 目录
    -l, --log-dir DIR           日志保存目录
    -m, --package-manager PM    包管理器 (yarn|npm|pnpm) [可选]
    -f, --config-file FILE      配置文件路径
    --skip-install              跳过依赖安装步骤
    --help                      显示此帮助信息

EXAMPLES:
    ./deploy.sh -p "/path/to/project" -n "my-app" -c "yarn build" -h "user@server.com" \
                -i "/home/user/images" -d "/home/user/compose" -l "/var/log/deploy"
    
    ./deploy.sh -f "./deploy.config"
    
    ./deploy.sh -f "./deploy.config" --skip-install  # 跳过依赖安装

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--project-dir)
                PROJECT_DIR="$2"
                shift 2
                ;;
            -n|--project-name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -c|--build-command)
                BUILD_COMMAND="$2"
                shift 2
                ;;
            -h|--remote-host)
                REMOTE_HOST="$2"
                shift 2
                ;;
            -i|--image-dir)
                REMOTE_IMAGE_DIR="$2"
                shift 2
                ;;
            -d|--compose-dir)
                REMOTE_COMPOSE_DIR="$2"
                shift 2
                ;;
            -l|--log-dir)
                LOG_DIR="$2"
                shift 2
                ;;
            -m|--package-manager)
                PACKAGE_MANAGER="$2"
                shift 2
                ;;
            -f|--config-file)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --skip-install)
                SKIP_INSTALL=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 验证必需参数
validate_args() {
    local missing=()
    
    [[ -z "$PROJECT_DIR" ]] && missing+=("项目目录 (-p)")
    [[ -z "$BUILD_COMMAND" ]] && missing+=("构建命令 (-c)")
    [[ -z "$REMOTE_HOST" ]] && missing+=("远程主机 (-h)")
    [[ -z "$REMOTE_IMAGE_DIR" ]] && missing+=("镜像目录 (-i)")
    [[ -z "$REMOTE_COMPOSE_DIR" ]] && missing+=("Compose目录 (-d)")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少必需参数:"
        for item in "${missing[@]}"; do
            echo "  - $item"
        done
        echo
        show_help
        exit 1
    fi
    
    # 验证项目目录是否存在
    if [[ ! -d "$PROJECT_DIR" ]]; then
        log_error "项目目录不存在: $PROJECT_DIR"
        exit 1
    fi
    
    # 验证包管理器
    if [[ -n "$PACKAGE_MANAGER" ]]; then
        case $PACKAGE_MANAGER in
            yarn|npm|pnpm) ;;
            *)
                log_error "不支持的包管理器: $PACKAGE_MANAGER (支持: yarn, npm, pnpm)"
                exit 1
                ;;
        esac
    fi
}

# 检测包管理器
detect_package_manager() {
    if [[ -n "$PACKAGE_MANAGER" ]]; then
        return
    fi
    
    if [[ -f "$PROJECT_DIR/yarn.lock" ]]; then
        PACKAGE_MANAGER="yarn"
    elif [[ -f "$PROJECT_DIR/package-lock.json" ]]; then
        PACKAGE_MANAGER="npm"
    elif [[ -f "$PROJECT_DIR/pnpm-lock.yaml" ]]; then
        PACKAGE_MANAGER="pnpm"
    else
        log_warn "无法自动检测包管理器，将使用 npm"
        PACKAGE_MANAGER="npm"
    fi
    
    log "检测到包管理器: $PACKAGE_MANAGER"
}

# 获取项目名称
get_project_name() {
    # 如果命令行参数提供了项目名称，则使用它
    if [[ -n "$PROJECT_NAME" ]]; then
        IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_')
        IMAGE_TAG="${IMAGE_NAME}:$TIMESTAMP"
        log "项目名称: $IMAGE_NAME"
        log "镜像标签: $IMAGE_TAG"
        return
    fi
    
    # 否则从 package.json 或目录名获取
    local package_json="$PROJECT_DIR/package.json"
    if [[ -f "$package_json" ]]; then
        # 使用 jq 提取 name 字段，如果 jq 不可用则使用 grep
        if command -v jq >/dev/null 2>&1; then
            IMAGE_NAME=$(jq -r '.name' "$package_json" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_')
        else
            IMAGE_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$package_json" 2>/dev/null | head -1 | cut -d'"' -f4 | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_')
        fi
    else
        # 使用目录名作为项目名
        IMAGE_NAME=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_')
    fi
    
    # 如果仍然为空，则使用默认名称
    if [[ -z "$IMAGE_NAME" ]]; then
        IMAGE_NAME="nextjs-app"
    fi
    
    IMAGE_TAG="${IMAGE_NAME}:$TIMESTAMP"
    log "项目名称: $IMAGE_NAME"
    log "镜像标签: $IMAGE_TAG"
}

# 初始化日志文件
init_log_file() {
    if [[ -n "$LOG_DIR" ]]; then
        # 创建日志目录（如果不存在）
        mkdir -p "$LOG_DIR"
        
        # 设置日志文件路径
        LOG_FILE="$LOG_DIR/${IMAGE_NAME}_${TIMESTAMP}.log"
        
        # 创建日志文件
        touch "$LOG_FILE"
        
        log_info "日志文件已初始化: $LOG_FILE"
    fi
}

# 从配置文件加载配置
load_config_file() {
    if [[ -n "$CONFIG_FILE" ]]; then
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log_error "配置文件不存在: $CONFIG_FILE"
            exit 1
        fi
        
        log_info "加载配置文件: $CONFIG_FILE"
        
        # 读取配置文件
        source "$CONFIG_FILE"
        
        # 验证必需的配置项
        local missing=()
        [[ -z "$PROJECT_DIR" ]] && missing+=("PROJECT_DIR")
        [[ -z "$BUILD_COMMAND" ]] && missing+=("BUILD_COMMAND")
        [[ -z "$REMOTE_HOST" ]] && missing+=("REMOTE_HOST")
        [[ -z "$REMOTE_IMAGE_DIR" ]] && missing+=("REMOTE_IMAGE_DIR")
        [[ -z "$REMOTE_COMPOSE_DIR" ]] && missing+=("REMOTE_COMPOSE_DIR")
        
        if [[ ${#missing[@]} -gt 0 ]]; then
            log_error "配置文件中缺少必需项: ${missing[*]}"
            exit 1
        fi
        
        log_info "配置文件加载完成"
    fi
}

# 安装项目依赖
install_dependencies() {
    log "开始安装项目依赖..."
    
    # 进入项目目录
    cd "$PROJECT_DIR"
    
    # 检查 package.json 是否存在
    if [[ ! -f "package.json" ]]; then
        log_warn "未找到 package.json 文件，跳过依赖安装"
        return
    fi
    
    # 检查包管理器是否已安装
    if ! command -v "$PACKAGE_MANAGER" >/dev/null 2>&1; then
        log_error "包管理器 $PACKAGE_MANAGER 未安装或不在 PATH 中"
        exit 1
    fi
    
    # 根据包管理器类型执行安装命令
    local install_command=""
    case $PACKAGE_MANAGER in
        yarn)
            # 检查是否有 yarn.lock，决定使用哪个安装命令
            if [[ -f "yarn.lock" ]]; then
                install_command="yarn install --frozen-lockfile"
                log_info "发现 yarn.lock，使用 frozen-lockfile 模式安装"
            else
                install_command="yarn install"
                log_info "未发现 yarn.lock，使用普通模式安装"
            fi
            ;;
        npm)
            # 检查是否有 package-lock.json，决定使用哪个安装命令
            if [[ -f "package-lock.json" ]]; then
                install_command="npm ci"
                log_info "发现 package-lock.json，使用 npm ci 安装"
            else
                install_command="npm install"
                log_info "未发现 package-lock.json，使用 npm install"
            fi
            ;;
        pnpm)
            # 检查是否有 pnpm-lock.yaml，决定使用哪个安装命令
            if [[ -f "pnpm-lock.yaml" ]]; then
                install_command="pnpm install --frozen-lockfile"
                log_info "发现 pnpm-lock.yaml，使用 frozen-lockfile 模式安装"
            else
                install_command="pnpm install"
                log_info "未发现 pnpm-lock.yaml，使用普通模式安装"
            fi
            ;;
        *)
            log_error "不支持的包管理器: $PACKAGE_MANAGER"
            exit 1
            ;;
    esac
    
    log "执行依赖安装命令: $install_command"
    
    # 显示安装进度
    local start_time=$(date +%s)
    if ! eval "$install_command"; then
        log_error "依赖安装失败"
        exit 1
    fi
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "项目依赖安装完成 (耗时: ${duration}秒)"
}

# 执行编译步骤
execute_build() {
    log "开始执行项目编译..."
    
    # 进入项目目录
    cd "$PROJECT_DIR"
    
    # 根据配置决定是否安装依赖
    if [[ "$SKIP_INSTALL" == "false" ]]; then
        install_dependencies
    else
        log_info "跳过依赖安装步骤"
    fi
    
    # 执行构建命令
    log "执行构建命令: $BUILD_COMMAND"
    if ! eval "$BUILD_COMMAND"; then
        log_error "构建失败"
        exit 1
    fi
    
    log "项目编译完成"
}

# 构建 Docker 镜像
build_docker_image() {
    log "开始构建 Docker 镜像..."
    
    # 检查 Dockerfile 是否存在
    if [[ ! -f "$PROJECT_DIR/Dockerfile" ]]; then
        log_error "项目目录中未找到 Dockerfile: $PROJECT_DIR/Dockerfile"
        exit 1
    fi
    
    # 进入项目目录
    cd "$PROJECT_DIR"
    
    # 构建镜像
    if ! docker build -t "$IMAGE_TAG" .; then
        log_error "Docker 镜像构建失败"
        exit 1
    fi
    
    log "Docker 镜像构建完成: $IMAGE_TAG"
}

# 保存镜像到文件
save_docker_image() {
    log "保存 Docker 镜像到文件..."
    
    # 创建临时目录
    mkdir -p "$TEMP_DIR"
    
    # 保存镜像
    local image_file="$TEMP_DIR/${IMAGE_NAME}_${TIMESTAMP}.tar"
    if ! docker save "$IMAGE_TAG" -o "$image_file"; then
        log_error "保存 Docker 镜像失败"
        exit 1
    fi
    
    IMAGE_FILE="$image_file"
    log "镜像已保存到: $IMAGE_FILE"
}

# 上传镜像到远程服务器
upload_image() {
    log "开始上传镜像到远程服务器..."
    
    # 创建远程镜像目录
    if ! ssh "$REMOTE_HOST" "mkdir -p $REMOTE_IMAGE_DIR"; then
        log_error "创建远程镜像目录失败"
        exit 1
    fi
    
    # 上传镜像文件
    if ! scp "$IMAGE_FILE" "$REMOTE_HOST:$REMOTE_IMAGE_DIR/"; then
        log_error "上传镜像文件失败"
        exit 1
    fi
    
    log "镜像上传完成"
}

# 在远程服务器上更新服务
update_remote_service() {
    log "开始更新远程服务器上的服务..."
    
    # 获取镜像文件名
    local image_filename=$(basename "$IMAGE_FILE")
    
    # 在远程服务器上执行更新操作
    local remote_commands="
        set -e
        echo '停止当前服务...'
        cd $REMOTE_COMPOSE_DIR && docker compose down || true
        
        echo '卸载旧镜像...'
        docker rmi $IMAGE_TAG || true
        
        echo '加载新镜像...'
        docker load -i $REMOTE_IMAGE_DIR/$image_filename
        
        echo '启动服务...'
        cd $REMOTE_COMPOSE_DIR && docker compose up -d
        
        echo '清理临时文件...'
        rm -f $REMOTE_IMAGE_DIR/$image_filename
        
        echo '检查服务状态...'
        sleep 5
        if ! cd $REMOTE_COMPOSE_DIR && docker compose ps | grep -q 'Up'; then
            echo '服务启动失败'
            exit 1
        fi
        
        echo '服务更新完成'
    "
    
    if ! ssh "$REMOTE_HOST" "$remote_commands"; then
        log_error "远程服务更新失败"
        return 1
    fi
    
    log "远程服务更新完成"
    return 0
}

# 回滚到上一个版本
rollback_service() {
    log_warn "新版本启动失败，开始回滚到上一个版本..."
    
    # 在远程服务器上执行回滚操作
    local rollback_commands="
        set -e
        echo '执行回滚操作...'
        cd $REMOTE_COMPOSE_DIR && docker compose down || true
        echo '回滚完成'
    "
    
    if ssh "$REMOTE_HOST" "$rollback_commands"; then
        log "回滚操作完成"
    else
        log_error "回滚操作失败"
    fi
}

# 清理临时文件
cleanup() {
    log "清理临时文件..."
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    log "清理完成"
}

# 信号处理，确保在脚本退出时清理
trap cleanup EXIT

# 主函数
main() {
    parse_args "$@"
    load_config_file
    validate_args
    detect_package_manager
    get_project_name
    init_log_file
    
    log "开始部署流程..."
    log "项目目录: $PROJECT_DIR"
    log "构建命令: $BUILD_COMMAND"
    log "远程主机: $REMOTE_HOST"
    log "镜像目录: $REMOTE_IMAGE_DIR"
    log "Compose目录: $REMOTE_COMPOSE_DIR"
    [[ -n "$LOG_FILE" ]] && log "日志文件: $LOG_FILE"
    [[ -n "$CONFIG_FILE" ]] && log "配置文件: $CONFIG_FILE"
    
    # 执行部署步骤
    execute_build || exit 1
    build_docker_image || exit 1
    save_docker_image || exit 1
    upload_image || exit 1
    
    # 尝试更新服务，如果失败则回滚
    if ! update_remote_service; then
        log_error "服务更新失败，正在执行回滚..."
        rollback_service
        exit 1
    fi
    
    log "部署流程完成"
}

# 执行主函数
main "$@"