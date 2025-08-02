#!/bin/bash

# 为前端项目初始化 Docker 配置的脚本
# 用法: ./init-docker-config.sh [项目名称]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
为前端项目初始化 Docker 配置的脚本

USAGE:
    ./init-docker-config.sh [OPTIONS] [PROJECT_NAME]

OPTIONS:
    -h, --help              显示此帮助信息
    -t, --type TYPE         指定项目类型 (nextjs|react|vue|angular|express)
    -p, --port PORT         指定应用端口 (默认: 3000)
    -c, --config FILE       使用配置文件 (默认: init-docker.config)
    --skip-scripts          跳过脚本文件创建
    --force                 强制覆盖已存在的文件

EXAMPLES:
    ./init-docker-config.sh my-app
    ./init-docker-config.sh -t nextjs -p 3001 my-app
    ./init-docker-config.sh --type react --port 8080 web-app
    ./init-docker-config.sh -c my-config.config my-app
    ./init-docker-config.sh --force my-app                # 强制覆盖现有文件

配置文件格式请参考 init-docker.config.example

EOF
}

# 全局变量
PROJECT_NAME=""
PROJECT_TYPE=""
APP_PORT="3000"
CONFIG_FILE=""
SKIP_SCRIPTS=false
FORCE_OVERWRITE=false
CURRENT_DIR=$(pwd)
BUILD_COMMAND="npm run build"
PACKAGE_MANAGER=""

# 加载配置文件
load_config() {
    local config_file="${CONFIG_FILE:-init-docker.config}"
    
    if [[ -f "$config_file" ]]; then
        log_info "加载配置文件: $config_file"
        
        # 保存当前值（命令行参数优先级更高）
        local current_project_name="$PROJECT_NAME"
        local current_project_type="$PROJECT_TYPE"
        local current_app_port="$APP_PORT"
        
        # 读取配置文件
        source "$config_file"
        
        # 应用配置到全局变量（命令行参数优先）
        if [[ -n "$PROJECT_DIR" ]]; then
            log_info "从配置文件设置项目目录: $PROJECT_DIR"
            cd "$PROJECT_DIR" || {
                log_error "无法切换到项目目录: $PROJECT_DIR"
                exit 1
            }
        fi
        
        # 如果命令行没有指定项目名称，使用配置文件中的
        if [[ -z "$current_project_name" ]] && [[ -n "$PROJECT_NAME" ]]; then
            log_info "从配置文件设置项目名称: $PROJECT_NAME"
        elif [[ -n "$current_project_name" ]]; then
            PROJECT_NAME="$current_project_name"
        fi
        
        # 如果命令行没有指定项目类型，使用配置文件中的
        if [[ -z "$current_project_type" ]] && [[ -n "$PROJECT_TYPE" ]]; then
            log_info "从配置文件设置项目类型: $PROJECT_TYPE"
        elif [[ -n "$current_project_type" ]]; then
            PROJECT_TYPE="$current_project_type"
        fi
        
        # 如果命令行没有指定端口，使用配置文件中的
        if [[ "$current_app_port" == "3000" ]] && [[ -n "$APP_PORT" ]] && [[ "$APP_PORT" != "3000" ]]; then
            log_info "从配置文件设置应用端口: $APP_PORT"
        elif [[ "$current_app_port" != "3000" ]]; then
            APP_PORT="$current_app_port"
        fi
        
        if [[ -n "$BUILD_COMMAND" ]]; then
            log_info "从配置文件设置构建命令: $BUILD_COMMAND"
        fi
        
        if [[ -n "$PACKAGE_MANAGER" ]]; then
            log_info "从配置文件设置包管理器: $PACKAGE_MANAGER"
        fi
        
        log "配置文件加载完成"
    elif [[ -n "$CONFIG_FILE" ]]; then
        log_error "指定的配置文件不存在: $CONFIG_FILE"
        exit 1
    else
        log_info "未找到配置文件，使用命令行参数和默认值"
    fi
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--type)
                PROJECT_TYPE="$2"
                shift 2
                ;;
            -p|--port)
                APP_PORT="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --skip-scripts)
                SKIP_SCRIPTS=true
                shift
                ;;
            --force)
                FORCE_OVERWRITE=true
                shift
                ;;
            -*)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
            *)
                PROJECT_NAME="$1"
                shift
                ;;
        esac
    done
}

# 检测项目类型
detect_project_type() {
    if [[ -n "$PROJECT_TYPE" ]]; then
        log_info "使用指定的项目类型: $PROJECT_TYPE"
        return
    fi
    
    log_info "检测项目类型..."
    
    # 检查 package.json
    if [[ ! -f "package.json" ]]; then
        log_error "当前目录中未找到 package.json 文件"
        exit 1
    fi
    
    # 检查特定文件来确定项目类型
    if [[ -f "next.config.js" ]] || grep -q "next" package.json; then
        PROJECT_TYPE="nextjs"
    elif grep -q "react-scripts" package.json; then
        PROJECT_TYPE="react"
    elif [[ -f "vue.config.js" ]] || grep -q "vue" package.json; then
        PROJECT_TYPE="vue"
    elif grep -q "@angular" package.json; then
        PROJECT_TYPE="angular"
    elif grep -q "express" package.json; then
        PROJECT_TYPE="express"
    else
        log_warn "无法自动检测项目类型，将使用默认的 Next.js 配置"
        PROJECT_TYPE="nextjs"
    fi
    
    log_info "检测到项目类型: $PROJECT_TYPE"
}

# 创建目录结构
create_directory_structure() {
    log_info "创建目录结构..."
    
    mkdir -p docker
    mkdir -p scripts
    
    log "目录结构创建完成"
}

# 生成 Dockerfile
generate_dockerfile() {
    log_info "生成 Dockerfile..."
    
    # 检查文件是否已存在
    if [[ -f "Dockerfile" ]] && [[ "$FORCE_OVERWRITE" == "false" ]]; then
        log_warn "Dockerfile 已存在，跳过生成以保留现有配置 (使用 --force 强制覆盖)"
        return
    elif [[ -f "Dockerfile" ]] && [[ "$FORCE_OVERWRITE" == "true" ]]; then
        log_warn "Dockerfile 已存在，强制覆盖"
    fi
    
    case $PROJECT_TYPE in
        "nextjs")
            cat > Dockerfile << 'EOF'
# 适用于 Next.js 的多阶段构建 Dockerfile，支持跨平台构建

# 构建阶段
FROM --platform=linux/amd64 node:18-alpine AS builder
WORKDIR /app

# 复制依赖文件
COPY package*.json ./
COPY yarn.lock* ./

# 安装依赖
RUN yarn install --frozen-lockfile || npm ci

# 复制源代码
COPY . .

# 构建应用
RUN yarn build || npm run build

# 生产运行阶段
FROM --platform=linux/amd64 node:18-alpine AS runner
WORKDIR /app

# 设置环境变量
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# 创建用户
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# 复制构建产物
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# 设置权限
USER nextjs

# 暴露端口
EXPOSE {{APP_PORT}}
ENV PORT={{APP_PORT}}
ENV HOSTNAME="0.0.0.0"

# 启动命令
CMD ["node", "server.js"]
EOF
            ;;
        "react"|"vue"|"angular")
            cat > Dockerfile << 'EOF'
# 适用于 React/Vue/Angular 等静态构建的多阶段 Dockerfile

# 构建阶段
FROM --platform=linux/amd64 node:18-alpine AS builder
WORKDIR /app

# 复制依赖文件
COPY package*.json ./
COPY yarn.lock* ./

# 安装依赖
RUN yarn install --frozen-lockfile || npm ci

# 复制源代码
COPY . .

# 构建应用
RUN yarn build || npm run build

# 生产运行阶段
FROM --platform=linux/amd64 nginx:alpine AS runner

# 复制构建产物
COPY --from=builder /app/{{BUILD_DIR}} /usr/share/nginx/html/

# 复制 Nginx 配置 (可选)
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露端口
EXPOSE {{APP_PORT}}

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]
EOF
            ;;
        "express")
            cat > Dockerfile << 'EOF'
# 适用于 Express.js 的 Dockerfile，支持跨平台构建
FROM --platform=linux/amd64 node:18-alpine
WORKDIR /app

# 复制依赖文件
COPY package*.json ./
COPY yarn.lock* ./

# 安装生产依赖
RUN yarn install --frozen-lockfile --production || npm ci --only=production

# 复制源代码
COPY . .

# 创建非 root 用户
RUN addgroup --system --gid 1001 appgroup
RUN adduser --system --uid 1001 appuser

# 设置权限
USER appuser

# 暴露端口
EXPOSE {{APP_PORT}}

# 启动命令
CMD ["node", "index.js"]
EOF
            ;;
    esac
    
    # 替换占位符
    sed -i '' "s/{{APP_PORT}}/$APP_PORT/g" Dockerfile
    if [[ "$PROJECT_TYPE" == "react" ]]; then
        sed -i '' "s/{{BUILD_DIR}}/build\//g" Dockerfile
    elif [[ "$PROJECT_TYPE" == "vue" ]] || [[ "$PROJECT_TYPE" == "angular" ]]; then
        sed -i '' "s/{{BUILD_DIR}}/dist\//g" Dockerfile
    fi
    
    log "Dockerfile 生成完成"
}

# 生成 docker-compose.yml
generate_docker_compose() {
    log_info "生成 docker-compose.yml..."
    
    # 检查文件是否已存在
    if [[ -f "docker/docker-compose.yml" ]] && [[ "$FORCE_OVERWRITE" == "false" ]]; then
        log_warn "docker/docker-compose.yml 已存在，跳过生成以保留现有配置 (使用 --force 强制覆盖)"
        return
    elif [[ -f "docker/docker-compose.yml" ]] && [[ "$FORCE_OVERWRITE" == "true" ]]; then
        log_warn "docker/docker-compose.yml 已存在，强制覆盖"
    fi
    
    cat > docker/docker-compose.yml << EOF
version: '3.8'

services:
  $PROJECT_NAME:
    build:
      context: ..
      dockerfile: Dockerfile
    image: $PROJECT_NAME:latest
    ports:
      - "$APP_PORT:$APP_PORT"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:$APP_PORT/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF
    
    log "docker-compose.yml 生成完成"
}

# 生成构建脚本
generate_build_script() {
    if $SKIP_SCRIPTS; then
        log_info "跳过构建脚本创建"
        return
    fi
    
    log_info "生成构建脚本..."
    
    # 检查文件是否已存在
    if [[ -f "scripts/build.sh" ]] && [[ "$FORCE_OVERWRITE" == "false" ]]; then
        log_warn "scripts/build.sh 已存在，跳过生成以保留现有配置 (使用 --force 强制覆盖)"
        return
    elif [[ -f "scripts/build.sh" ]] && [[ "$FORCE_OVERWRITE" == "true" ]]; then
        log_warn "scripts/build.sh 已存在，强制覆盖"
    fi
    
    cat > scripts/build.sh << 'EOF'
#!/bin/bash
set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 获取项目名称和端口
PROJECT_NAME="{{PROJECT_NAME}}"
APP_PORT="{{APP_PORT}}"

# 构建应用
build_app() {
    print_info "构建应用..."
    
    # 检测包管理器
    local pm="{{PACKAGE_MANAGER}}"
    if [[ -z "$pm" ]]; then
        if [[ -f "yarn.lock" ]]; then
            pm="yarn"
        elif [[ -f "pnpm-lock.yaml" ]]; then
            pm="pnpm"
        else
            pm="npm"
        fi
        print_info "自动检测到包管理器: $pm"
    fi
    
    # 根据项目类型执行构建命令
    case "{{PROJECT_TYPE}}" in
        "nextjs"|"react"|"vue"|"angular")
            # 使用配置文件中的构建命令，如果没有则使用默认
            local build_cmd="{{BUILD_COMMAND}}"
            if [[ "$build_cmd" == "npm run build" ]] && [[ "$pm" != "npm" ]]; then
                build_cmd="$pm run build"
            fi
            print_info "执行构建命令: $build_cmd"
            eval $build_cmd
            ;;
        "express")
            # Express.js 项目无需构建
            print_info "Express.js 项目无需构建"
            ;;
    esac
    
    print_success "应用构建完成！"
}

# 构建 Docker 镜像
build_docker() {
    print_info "构建 Docker 镜像..."
    
    # 检测当前平台
    local current_arch=$(uname -m)
    local platform_flag="--platform linux/amd64"
    
    # 检查是否传入了平台参数
    local target_platform="${1:-linux/amd64}"
    
    if [[ "$target_platform" != "native" ]]; then
        platform_flag="--platform $target_platform"
        print_info "构建 $target_platform 镜像"
        
        # 如果当前是 ARM64 架构但要构建 AMD64，给出提示
        if [[ "$current_arch" == "arm64" ]] || [[ "$current_arch" == "aarch64" ]]; then
            if [[ "$target_platform" == "linux/amd64" ]]; then
                print_info "检测到 ARM64 架构，将构建 Linux/AMD64 镜像以确保服务器兼容性"
                print_info "这可能需要较长时间，因为需要模拟 AMD64 环境"
            fi
        fi
    else
        platform_flag=""
        print_info "构建原生架构镜像"
    fi
    
    docker build $platform_flag -t $PROJECT_NAME:latest .
    print_success "Docker 镜像构建完成！"
    
    # 显示镜像信息
    print_info "镜像详情:"
    docker image inspect $PROJECT_NAME:latest --format "  架构: {{.Architecture}}"
    docker image inspect $PROJECT_NAME:latest --format "  操作系统: {{.Os}}"
    docker image inspect $PROJECT_NAME:latest --format "  大小: {{.Size}}" | awk '{printf "  大小: %.2f MB\n", $2/1024/1024}'
}

# 主逻辑
build_app
build_docker

print_success "构建完成！"
EOF
    
    # 替换占位符
    sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" scripts/build.sh
    sed -i '' "s/{{APP_PORT}}/$APP_PORT/g" scripts/build.sh
    sed -i '' "s/{{PROJECT_TYPE}}/$PROJECT_TYPE/g" scripts/build.sh
    sed -i '' "s|{{BUILD_COMMAND}}|$BUILD_COMMAND|g" scripts/build.sh
    sed -i '' "s/{{PACKAGE_MANAGER}}/$PACKAGE_MANAGER/g" scripts/build.sh
    
    # 添加执行权限
    chmod +x scripts/build.sh
    
    log "构建脚本生成完成"
}

# 生成部署脚本
generate_deploy_script() {
    if $SKIP_SCRIPTS; then
        log_info "跳过部署脚本创建"
        return
    fi
    
    log_info "生成部署脚本..."
    
    # 检查文件是否已存在
    if [[ -f "scripts/deploy.sh" ]] && [[ "$FORCE_OVERWRITE" == "false" ]]; then
        log_warn "scripts/deploy.sh 已存在，跳过生成以保留现有配置 (使用 --force 强制覆盖)"
        return
    elif [[ -f "scripts/deploy.sh" ]] && [[ "$FORCE_OVERWRITE" == "true" ]]; then
        log_warn "scripts/deploy.sh 已存在，强制覆盖"
    fi
    
    cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 获取项目名称和端口
PROJECT_NAME="{{PROJECT_NAME}}"
APP_PORT="{{APP_PORT}}"

# 部署应用
deploy_app() {
    print_info "部署应用..."
    
    # 停止并移除现有容器（如果存在）
    docker stop $PROJECT_NAME 2>/dev/null || true
    docker rm $PROJECT_NAME 2>/dev/null || true
    
    # 运行新容器
    docker run -d -p $APP_PORT:$APP_PORT --name $PROJECT_NAME $PROJECT_NAME:latest
    
    print_success "应用部署完成！"
    print_info "应用访问地址: http://localhost:$APP_PORT"
}

# 查看日志
view_logs() {
    print_info "查看应用日志..."
    docker logs -f $PROJECT_NAME
}

# 停止应用
stop_app() {
    print_info "停止应用..."
    docker stop $PROJECT_NAME 2>/dev/null || true
    print_success "应用已停止"
}

# 主逻辑
case ${1:-deploy} in
    "deploy")
        deploy_app
        ;;
    "logs")
        view_logs
        ;;
    "stop")
        stop_app
        ;;
    *)
        echo "用法: $0 [deploy|logs|stop]"
        exit 1
        ;;
esac
EOF
    
    # 替换占位符
    sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" scripts/deploy.sh
    sed -i '' "s/{{APP_PORT}}/$APP_PORT/g" scripts/deploy.sh
    sed -i '' "s/{{PROJECT_TYPE}}/$PROJECT_TYPE/g" scripts/deploy.sh
    
    # 添加执行权限
    chmod +x scripts/deploy.sh
    
    log "部署脚本生成完成"
}

# 生成 Makefile
generate_makefile() {
    if $SKIP_SCRIPTS; then
        log_info "跳过 Makefile 创建"
        return
    fi
    
    log_info "生成 Makefile..."
    
    # 检查文件是否已存在
    if [[ -f "Makefile" ]] && [[ "$FORCE_OVERWRITE" == "false" ]]; then
        log_warn "Makefile 已存在，跳过生成以保留现有配置 (使用 --force 强制覆盖)"
        return
    elif [[ -f "Makefile" ]] && [[ "$FORCE_OVERWRITE" == "true" ]]; then
        log_warn "Makefile 已存在，强制覆盖"
    fi
    
    cat > Makefile << EOF
# 项目 Docker 管理 Makefile

.PHONY: help build up down logs clean

help: ## 显示帮助信息
	@echo "可用命令："
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-15s %s\n", \$$1, \$$2 }' \$(MAKEFILE_LIST)

build: ## 构建应用和 Docker 镜像
	./scripts/build.sh

up: ## 启动应用
	./scripts/deploy.sh deploy

down: ## 停止应用
	./scripts/deploy.sh stop

logs: ## 查看应用日志
	./scripts/deploy.sh logs

clean: ## 清理容器和镜像
	docker stop $PROJECT_NAME 2>/dev/null || true
	docker rm $PROJECT_NAME 2>/dev/null || true
	docker rmi $PROJECT_NAME:latest 2>/dev/null || true

setup: build up ## 一键设置：构建并启动应用
	@echo "✅ 应用已启动！访问地址: http://localhost:$APP_PORT"
EOF
    
    log "Makefile 生成完成"
}

# 生成 .dockerignore
generate_dockerignore() {
    log_info "生成 .dockerignore..."
    
    # 检查文件是否已存在
    if [[ -f ".dockerignore" ]] && [[ "$FORCE_OVERWRITE" == "false" ]]; then
        log_warn ".dockerignore 已存在，跳过生成以保留现有配置 (使用 --force 强制覆盖)"
        return
    elif [[ -f ".dockerignore" ]] && [[ "$FORCE_OVERWRITE" == "true" ]]; then
        log_warn ".dockerignore 已存在，强制覆盖"
    fi
    
    cat > .dockerignore << 'EOF'
# Dependencies
node_modules

# Build outputs
.next
build
dist
out

# Environment files
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
logs
*.log

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Directory for instrumented libs generated by jscoverage/JSCover
lib-cov

# Coverage directory used by tools like istanbul
coverage
*.lcov

# nyc test coverage
.nyc_output

# Grunt intermediate storage (https://gruntjs.com/creating-plugins#storing-task-files)
.grunt

# Bower dependency directory (https://bower.io/)
bower_components

# node-waf configuration
.lock-wscript

# Compiled binary addons (https://nodejs.org/api/addons.html)
build/Release

# Dependency directories
jspm_packages

# TypeScript v1 declaration files
typings

# TypeScript cache
*.tsbuildinfo

# Optional npm cache directory
.npm

# Optional eslint cache
.eslintcache

# Microbundle cache
.rpt2_cache
.rts2_cache_cjs
.rts2_cache_es
.rts2_cache_umd

# Optional REPL history
.node_repl_history

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity

# dotenv environment variables file
.env.test

# parcel-bundler cache (https://parceljs.org/)
.cache

# Next.js build output
.next

# Nuxt.js build / generation output
.nuxt
dist

# Gatsby files
.cache/
public/

# vuepress build output
.vuepress/dist

# Serverless directories
.serverless/

# FuseBox cache
.fusebox/

# DynamoDB Local files
.dynamodb/

# TernJS port file
.tern-port

# Stores VSCode versions used for testing VSCode extensions
.vscode-test

# yarn v2
.yarn/cache
.yarn/unplugged
.yarn/build-state.yml
.yarn/install-state.gz
.pnp.*
EOF
    
    log ".dockerignore 生成完成"
}

# 更新项目配置
update_project_config() {
    log_info "更新项目配置..."
    
    case $PROJECT_TYPE in
        "nextjs")
            # 检查是否存在 next.config.js 并给出配置建议
            if [[ -f "next.config.js" ]]; then
                # 检查是否已有 output: 'standalone' 配置
                if ! grep -q "output.*standalone" next.config.js; then
                    log_warn "请确保 next.config.js 中包含 output: 'standalone' 配置以支持 Docker 部署"
                fi
                if ! grep -q "ignoreDuringBuilds.*true" next.config.js; then
                    log_warn "建议在 next.config.js 中添加 eslint: { ignoreDuringBuilds: true } 配置"
                fi
            else
                log_warn "未找到 next.config.js 文件"
                log_warn "为了支持 Docker 部署，请确保项目中包含以下配置："
                log_warn "  output: 'standalone'"
                log_warn "  eslint: { ignoreDuringBuilds: true }"
            fi
            ;;
        *)
            # 对于其他项目类型，暂时不修改配置
            ;;
    esac
    
    log "项目配置更新完成"
}

# 显示使用说明
show_usage_instructions() {
    log_info "使用说明:"
    echo
    echo "1. 项目配置要求:"
    echo "   - Next.js 项目需要在 next.config.js 中添加 output: 'standalone' 配置"
    echo "   - 建议添加 eslint: { ignoreDuringBuilds: true } 配置"
    echo
    echo "2. 配置文件说明:"
    echo "   - 可以使用 init-docker.config 配置文件来设置默认参数"
    echo "   - 配置文件格式请参考 init-docker.config.example"
    echo "   - 命令行参数的优先级高于配置文件"
    echo
    echo "3. 设置脚本执行权限:"
    echo "   chmod +x scripts/*.sh"
    echo
    echo "4. 构建和部署应用:"
    echo "   方法一（使用 Makefile）:"
    echo "     make setup     # 一键构建并部署"
    echo "     make build     # 仅构建"
    echo "     make up        # 仅部署"
    echo "     make logs      # 查看日志"
    echo "     make down      # 停止应用"
    echo "     make clean     # 清理容器和镜像"
    echo
    echo "   方法二（直接运行脚本）:"
    echo "     ./scripts/build.sh                    # 构建应用和镜像 (默认 Linux/AMD64)"
    echo "     ./scripts/build.sh linux/arm64        # 构建 ARM64 架构镜像"
    echo "     ./scripts/build.sh native             # 构建原生架构镜像"
    echo "     ./scripts/deploy.sh                   # 部署应用"
    echo
    echo "   跨平台构建说明:"
    echo "     - 默认构建 Linux/AMD64 镜像，适用于大多数云服务器"
    echo "     - 在 Apple Silicon (M1/M2) 上构建 AMD64 镜像可能较慢"
    echo "     - 使用 'native' 参数可构建当前平台原生镜像，速度更快"
    echo
    echo "5. 访问应用:"
    echo "   打开浏览器访问 http://localhost:$APP_PORT"
    echo
}

# 主函数
main() {
    parse_args "$@"
    load_config
    
    # 如果没有提供项目名称，使用当前目录名
    if [[ -z "$PROJECT_NAME" ]]; then
        PROJECT_NAME=$(basename "$CURRENT_DIR")
    fi
    
    log "开始为项目 '$PROJECT_NAME' 初始化 Docker 配置..."
    
    detect_project_type
    create_directory_structure
    generate_dockerfile
    generate_docker_compose
    generate_build_script
    generate_deploy_script
    generate_makefile
    generate_dockerignore
    update_project_config
    show_usage_instructions
    
    log "Docker 配置初始化完成！"
}

# 执行主函数
main "$@"