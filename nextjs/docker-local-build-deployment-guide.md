# Docker 本地构建部署方案指南

> 适用于 Next.js/React 及类似前端项目的 Docker 化部署最佳实践

## 📋 方案概述

本方案解决了在网络环境受限或构建依赖复杂的情况下，通过**本地构建 + Docker 容器化部署**的策略，实现简单、高效、稳定的生产级部署。

### 🎯 核心思路

1. **本地构建应用** - 在开发环境完成应用构建
2. **Docker 复制文件** - 将构建产物复制到容器中
3. **镜像化部署** - 使用镜像模式进行快速部署

### ✅ 方案优势

- ✨ **网络无关性** - 避免容器内网络依赖问题
- ⚡ **构建速度快** - 利用本地缓存和高速网络
- 🔒 **构建稳定性** - 本地环境可控，避免构建失败
- 🚀 **部署效率高** - 镜像小，启动快
- 🛠️ **易于调试** - 构建问题在本地解决
- 📦 **通用性强** - 适用于各种前端框架

## 🏗️ 实施步骤

### 第一步：项目准备

#### 1.1 创建目录结构
```
your-project/
├── docker/                    # Docker 配置目录
│   ├── docker-compose.yml     # 部署配置
│   └── docker-compose.build.yml # 构建配置
├── scripts/                   # 自动化脚本
├── Dockerfile                 # 生产 Dockerfile
├── Dockerfile.dev            # 开发 Dockerfile (可选)
└── Makefile                  # 便捷命令 (可选)
```

#### 1.2 配置项目构建

确保项目支持独立构建输出：

**Next.js 项目**：
```javascript
// next.config.js
const nextConfig = {
  output: 'standalone',
  eslint: {
    ignoreDuringBuilds: true, // 避免构建时 ESLint 错误
  },
};
```

**React 项目**：
```json
// package.json
{
  "scripts": {
    "build": "react-scripts build"
  }
}
```

### 第二步：创建 Dockerfile

#### 2.1 生产环境 Dockerfile

```dockerfile
# 适用于 Next.js 的生产 Dockerfile
FROM node:18-alpine AS runner
WORKDIR /app

# 设置环境变量
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# 创建用户
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# 复制构建产物
COPY .next/standalone ./
COPY .next/static ./.next/static
COPY public ./public

# 设置权限
USER nextjs

# 暴露端口
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# 启动命令
CMD ["node", "server.js"]
```

#### 2.2 React/其他项目 Dockerfile

```dockerfile
# 适用于 React 等静态构建的 Dockerfile
FROM nginx:alpine AS runner

# 复制构建产物
COPY build/ /usr/share/nginx/html/

# 复制 Nginx 配置 (可选)
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露端口
EXPOSE 80

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]
```

### 第三步：配置 Docker Compose

#### 3.1 部署配置 (docker/docker-compose.yml)

```yaml
version: '3.8'

services:
  # 生产服务
  your-app:
    image: your-app:latest
    ports:
      - "3000:3000"  # 根据需要调整端口
    environment:
      - NODE_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # 开发服务 (可选)
  your-app-dev:
    image: your-app:dev-latest
    ports:
      - "3001:3000"
    volumes:
      - ..:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
    profiles:
      - dev
    restart: unless-stopped
```

#### 3.2 构建配置 (docker/docker-compose.build.yml)

```yaml
version: '3.8'

services:
  # 生产构建
  your-app-build:
    build:
      context: ..
      dockerfile: Dockerfile
    image: your-app:latest
    profiles:
      - build

  # 开发构建 (可选)
  your-app-dev-build:
    build:
      context: ..
      dockerfile: Dockerfile.dev
    image: your-app:dev-latest
    profiles:
      - build-dev
```

### 第四步：创建自动化脚本

#### 4.1 构建脚本 (scripts/docker-build.sh)

```bash
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

# 构建生产镜像
build_production() {
    print_info "构建生产镜像..."
    
    # 本地构建应用
    print_info "执行本地构建..."
    npm run build
    
    # 构建 Docker 镜像
    print_info "构建 Docker 镜像..."
    docker build -t your-app:latest .
    
    print_success "生产镜像构建成功！"
}

# 构建开发镜像
build_development() {
    print_info "构建开发镜像..."
    docker build -f Dockerfile.dev -t your-app:dev-latest .
    print_success "开发镜像构建成功！"
}

# 主逻辑
case ${1:-production} in
    "production")
        build_production
        ;;
    "development")
        build_development
        ;;
    "all")
        build_production
        build_development
        ;;
    *)
        echo "用法: $0 [production|development|all]"
        exit 1
        ;;
esac

print_success "构建完成！"
```

#### 4.2 部署脚本 (scripts/docker-deploy.sh)

```bash
#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

ENVIRONMENT=${1:-prod}
BUILD_FLAG=${2}

# 部署生产环境
deploy_prod() {
    print_info "部署生产环境..."
    
    if [ "$BUILD_FLAG" = "--build" ]; then
        print_info "先构建镜像..."
        ./scripts/docker-build.sh production
    fi
    
    docker-compose -f docker/docker-compose.yml up -d your-app
    print_success "生产环境部署成功！"
}

# 部署开发环境
deploy_dev() {
    print_info "部署开发环境..."
    
    if [ "$BUILD_FLAG" = "--build" ]; then
        print_info "先构建开发镜像..."
        ./scripts/docker-build.sh development
    fi
    
    docker-compose -f docker/docker-compose.yml --profile dev up -d your-app-dev
    print_success "开发环境部署成功！"
}

# 主逻辑
case $ENVIRONMENT in
    "prod")
        deploy_prod
        ;;
    "dev")
        deploy_dev
        ;;
    *)
        echo "用法: $0 [prod|dev] [--build]"
        exit 1
        ;;
esac
```

### 第五步：创建便捷命令 (Makefile)

```makefile
# 项目 Docker 管理 Makefile

.PHONY: help build up down logs clean

help: ## 显示帮助信息
	@echo "可用命令："
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## 构建生产镜像
	./scripts/docker-build.sh production

build-dev: ## 构建开发镜像
	./scripts/docker-build.sh development

up: ## 启动生产环境
	./scripts/docker-deploy.sh prod

up-build: ## 构建并启动生产环境
	./scripts/docker-deploy.sh prod --build

up-dev: ## 启动开发环境
	./scripts/docker-deploy.sh dev

down: ## 停止所有服务
	docker-compose -f docker/docker-compose.yml down

logs: ## 查看生产日志
	docker-compose -f docker/docker-compose.yml logs -f your-app

logs-dev: ## 查看开发日志
	docker-compose -f docker/docker-compose.yml logs -f your-app-dev

clean: ## 清理容器和镜像
	docker-compose -f docker/docker-compose.yml down --remove-orphans
	docker image prune -f

setup: build up ## 一键设置：构建并启动生产环境
	@echo "✅ 生产环境已启动！"

setup-dev: build-dev up-dev ## 一键设置：构建并启动开发环境
	@echo "✅ 开发环境已启动！"
```

## 🔧 实际应用流程

### 初次部署

```bash
# 1. 设置脚本权限
chmod +x scripts/*.sh

# 2. 一键部署生产环境
make setup

# 或分步执行
make build    # 构建镜像
make up       # 启动服务
```

### 日常开发

```bash
# 开发环境
make setup-dev

# 查看日志
make logs-dev

# 重新构建并部署
make up-build
```

### 生产更新

```bash
# 停止服务
make down

# 重新构建并部署
make up-build

# 查看状态
docker ps
```

## 🚨 常见问题与解决方案

### 问题1：端口冲突
```bash
# 解决方案：修改 docker-compose.yml 中的端口映射
ports:
  - "3002:3000"  # 改用其他端口
```

### 问题2：构建失败
```bash
# 解决方案：在 next.config.js 中禁用 ESLint
eslint: {
  ignoreDuringBuilds: true,
}
```

### 问题3：文件权限问题
```bash
# 解决方案：设置正确的用户权限
RUN chown -R nextjs:nodejs /app
USER nextjs
```

### 问题4：静态文件缺失
```bash
# 解决方案：确保复制所有必要文件
COPY .next/standalone ./
COPY .next/static ./.next/static
COPY public ./public
```

## 📊 性能优化建议

### 1. 镜像优化
- 使用 Alpine 基础镜像减小体积
- 多阶段构建分离构建和运行环境
- 合理使用 .dockerignore

### 2. 构建优化
- 利用本地 npm 缓存
- 启用 Docker 构建缓存
- 并行构建多个镜像

### 3. 部署优化
- 使用健康检查确保服务可用
- 配置资源限制
- 设置合理的重启策略

## 🔄 适配其他项目

### Vue.js 项目适配

```dockerfile
# Vue.js Dockerfile
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Angular 项目适配

```dockerfile
# Angular Dockerfile
FROM nginx:alpine
COPY dist/your-app/ /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Express.js 项目适配

```dockerfile
# Express.js Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "index.js"]
```

## 📝 总结

这个方案通过**本地构建 + Docker 部署**的策略，有效解决了网络环境限制和构建复杂性问题，提供了一个简单、稳定、高效的 Docker 化部署解决方案。

**关键优势**：
- 🎯 **简单易用** - 一键构建部署
- ⚡ **快速稳定** - 避免网络问题
- 🔧 **易于维护** - 清晰的目录结构
- 🚀 **通用性强** - 适配多种项目类型

按照本指南，你可以快速为任何前端项目实现 Docker 化部署！ 