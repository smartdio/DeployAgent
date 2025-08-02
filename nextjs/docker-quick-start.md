# Docker 本地构建部署 - 快速上手

> 5分钟快速实现项目 Docker 化部署

## 🚀 一键复制配置

### 1. 创建目录结构

```bash
mkdir -p docker scripts
```

### 2. 复制核心文件

#### Dockerfile (生产环境)
```dockerfile
FROM node:18-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# 根据项目类型选择复制方式
# Next.js 项目：
COPY .next/standalone ./
COPY .next/static ./.next/static
COPY public ./public

# React 项目 (使用 nginx)：
# FROM nginx:alpine
# COPY build/ /usr/share/nginx/html/
# EXPOSE 80
# CMD ["nginx", "-g", "daemon off;"]

USER nextjs
EXPOSE 3000
ENV PORT=3000 HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
```

#### docker/docker-compose.yml
```yaml
version: '3.8'
services:
  app:
    image: your-app:latest
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
```

#### scripts/build-and-deploy.sh
```bash
#!/bin/bash
set -e

APP_NAME=${1:-your-app}
PORT=${2:-3000}

echo "🏗️  本地构建应用..."
npm run build

echo "🐳 构建 Docker 镜像..."
docker build -t $APP_NAME:latest .

echo "🚀 启动应用..."
docker run -d -p $PORT:3000 --name $APP_NAME $APP_NAME:latest

echo "✅ 部署完成！应用运行在 http://localhost:$PORT"
```

#### Makefile (可选)
```makefile
.PHONY: help setup clean
help:
	@echo "make setup  - 一键构建并部署"
	@echo "make clean  - 清理容器和镜像"

setup:
	npm run build
	docker build -t app:latest .
	docker run -d -p 3000:3000 --name app app:latest
	@echo "✅ 应用已启动: http://localhost:3000"

clean:
	-docker stop app && docker rm app
	-docker rmi app:latest
```

### 3. 项目配置调整

#### Next.js - next.config.js
```javascript
module.exports = {
  output: 'standalone',
  eslint: { ignoreDuringBuilds: true },
};
```

#### React - 无需额外配置
```json
{
  "scripts": {
    "build": "react-scripts build"
  }
}
```

## ⚡ 快速部署

### 方式1：使用脚本
```bash
chmod +x scripts/build-and-deploy.sh
./scripts/build-and-deploy.sh my-app 3001
```

### 方式2：使用 Makefile
```bash
make setup
```

### 方式3：手动执行
```bash
# 1. 本地构建
npm run build

# 2. 构建镜像
docker build -t my-app:latest .

# 3. 运行容器
docker run -d -p 3000:3000 --name my-app my-app:latest
```

## 🔧 常用命令

```bash
# 查看运行状态
docker ps

# 查看日志
docker logs my-app

# 停止应用
docker stop my-app

# 重新部署
docker stop my-app && docker rm my-app
make setup
```

## 🏷️ 标签化管理

```bash
# 创建版本标签
docker tag my-app:latest my-app:v1.0.0

# 推送到仓库 (可选)
docker push your-registry/my-app:v1.0.0
```

## 📋 检查清单

- [ ] 项目能正常执行 `npm run build`
- [ ] 根据项目类型调整 Dockerfile
- [ ] 设置脚本执行权限
- [ ] 检查端口是否冲突
- [ ] 测试应用访问

## 🚨 故障排除

| 问题 | 解决方案 |
|------|----------|
| 端口冲突 | 修改 `-p 3001:3000` 使用其他端口 |
| 构建失败 | 在 next.config.js 中禁用 ESLint |
| 文件缺失 | 检查 COPY 路径是否正确 |
| 权限错误 | 确保使用正确的用户 (nextjs) |

---

**完整方案详见**: [docker-local-build-deployment-guide.md](./docker-local-build-deployment-guide.md) 