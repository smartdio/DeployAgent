# Docker 本地构建部署 - 项目模板清单

> 新项目快速应用 Docker 化部署的检查清单

## 📁 文件结构清单

```
your-new-project/
├── 📁 docker/
│   ├── 📄 docker-compose.yml        ✅ 复制并修改服务名
│   └── 📄 docker-compose.build.yml  ✅ 复制并修改镜像名
├── 📁 scripts/
│   ├── 📄 docker-build.sh           ✅ 复制并修改镜像名
│   ├── 📄 docker-deploy.sh          ✅ 复制并修改服务名
│   ├── 📄 docker-logs.sh            ✅ 复制并修改服务名
│   └── 📄 docker-cleanup.sh         ✅ 复制
├── 📄 Dockerfile                    ✅ 根据项目类型选择
├── 📄 Dockerfile.dev                ✅ 可选，开发环境用
├── 📄 Makefile                      ✅ 复制并修改变量
├── 📄 .dockerignore                 ✅ 复制
└── 📄 项目配置文件                    ✅ 修改构建配置
```

## 🔧 配置修改清单

### 1. 项目类型识别

| 项目类型 | 构建命令 | 输出目录 | Dockerfile选择 |
|----------|----------|----------|----------------|
| Next.js | `npm run build` | `.next/` | ✅ Node.js + standalone |
| React (CRA) | `npm run build` | `build/` | ✅ Nginx + static |
| Vue.js | `npm run build` | `dist/` | ✅ Nginx + static |
| Angular | `ng build` | `dist/` | ✅ Nginx + static |
| Express.js | 无需构建 | 源码 | ✅ Node.js + 源码 |

### 2. 项目配置修改

#### ✅ Next.js 项目
```javascript
// next.config.js
module.exports = {
  output: 'standalone',           // 🔑 关键配置
  eslint: { 
    ignoreDuringBuilds: true     // 🔑 避免构建失败
  },
};
```

#### ✅ React 项目 (无需修改)
```json
// package.json (确认存在)
{
  "scripts": {
    "build": "react-scripts build"
  }
}
```

#### ✅ Vue.js 项目
```javascript
// vue.config.js (可选)
module.exports = {
  outputDir: 'dist',
  assetsDir: 'static',
};
```

### 3. Docker 配置修改

#### ✅ 修改 docker-compose.yml
```yaml
# 替换所有出现的项目名称
services:
  your-new-app:  # 🔧 改为你的项目名
    image: your-new-app:latest  # 🔧 改为你的镜像名
    ports:
      - "3000:3000"  # 🔧 根据需要调整端口
```

#### ✅ 修改构建脚本
```bash
# scripts/docker-build.sh
IMAGE_NAME="your-new-app"  # 🔧 改为你的项目名

# scripts/docker-deploy.sh  
# 找到并替换所有服务名引用
```

#### ✅ 修改 Makefile
```makefile
# Makefile
DOCKER_COMPOSE := docker-compose -f docker/docker-compose.yml
SERVICE_NAME := your-new-app  # 🔧 改为你的服务名
```

### 4. Dockerfile 选择与修改

#### ✅ Next.js Dockerfile
```dockerfile
# 无需修改，直接使用
FROM node:18-alpine AS runner
# ... 保持原配置 ...
```

#### ✅ React/Vue/Angular Dockerfile  
```dockerfile
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/  # 🔧 根据输出目录调整
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

#### ✅ Express.js Dockerfile
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000  # 🔧 根据应用端口调整
CMD ["node", "server.js"]  # 🔧 根据启动文件调整
```

## 🚀 部署测试清单

### ✅ 基础测试

```bash
# 1. 确认本地构建正常
npm install
npm run build  # 🔑 必须成功

# 2. 设置脚本权限
chmod +x scripts/*.sh

# 3. 构建镜像测试
make build
# 或 ./scripts/docker-build.sh

# 4. 部署测试
make up
# 或 ./scripts/docker-deploy.sh prod

# 5. 访问测试
curl http://localhost:3000  # 🔑 返回200状态
```

### ✅ 健康检查测试

```bash
# 如果有健康检查API
curl http://localhost:3000/api/health
curl http://localhost:3000/health

# 检查容器状态
docker ps  # 🔑 状态应为 Up (healthy)
```

### ✅ 日志检查

```bash
# 查看启动日志
make logs
# 或 docker logs your-app-name

# 🔑 确认无错误输出
```

## 📝 自定义配置清单

### ✅ 端口配置
- [ ] 修改 docker-compose.yml 端口映射
- [ ] 检查本地端口是否冲突
- [ ] 更新文档中的访问地址

### ✅ 环境变量
```yaml
# docker-compose.yml
environment:
  - NODE_ENV=production
  - API_URL=https://your-api.com  # 🔧 添加项目特定变量
  - DATABASE_URL=${DATABASE_URL}  # 🔧 从宿主机传递
```

### ✅ 数据卷 (如需要)
```yaml
# docker-compose.yml
volumes:
  - ./data:/app/data  # 🔧 持久化数据
  - ./logs:/app/logs  # 🔧 日志输出
```

### ✅ 网络配置 (如需要)
```yaml
# docker-compose.yml
networks:
  - app-network  # 🔧 自定义网络

networks:
  app-network:
    driver: bridge
```

## 🎯 项目特定调整

### ✅ 数据库项目
- [ ] 添加数据库服务到 docker-compose.yml
- [ ] 配置数据库连接环境变量
- [ ] 添加数据初始化脚本

### ✅ 微服务项目
- [ ] 为每个服务创建独立的 Dockerfile
- [ ] 配置服务间网络通信
- [ ] 设置服务发现机制

### ✅ 需要构建工具的项目
- [ ] 确保构建工具在容器中可用
- [ ] 配置构建缓存策略
- [ ] 优化构建时间

## ✅ 最终检查清单

- [ ] 项目本地构建成功
- [ ] Docker 镜像构建成功  
- [ ] 容器启动成功
- [ ] 应用访问正常
- [ ] 健康检查通过
- [ ] 日志输出正常
- [ ] 脚本执行权限正确
- [ ] 端口配置无冲突
- [ ] 环境变量配置正确
- [ ] 文档更新完成

## 📚 相关文档

- [完整部署指南](./docker-local-build-deployment-guide.md)
- [快速上手指南](./docker-quick-start.md)
- [故障排除手册](./docker-local-build-deployment-guide.md#常见问题与解决方案)

---

**完成所有检查项后，你的项目就可以成功实现 Docker 化部署了！** 🎉 