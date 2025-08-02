# DeployAgent 多语言架构扩展计划

## 1. 项目愿景

将 DeployAgent 发展为一个支持主流编程语言的自动化构建与部署工具，专注于实用性和易用性。

## 2. 核心语言支持规划

### 2.1 当前支持 (已实现)
- **Node.js**: Next.js, React, Vue.js, Angular, Express.js

### 2.2 计划扩展的语言与框架

#### A. 目标语言支持
```
├── 🐹 Go
│   ├── Gin
│   ├── Echo
│   ├── Fiber
│   └── 标准库 HTTP
├── 🐍 Python
│   ├── FastAPI
│   ├── Django
│   ├── Flask
│   └── Streamlit
├── ☕ Java
│   ├── Spring Boot
│   ├── Maven 项目
│   └── Gradle 项目
├── 📘 Node.js (扩展)
│   ├── NestJS
│   ├── Koa
│   └── Fastify
└── 🐘 PHP
    ├── Laravel
    ├── Symfony
    └── CodeIgniter
```

#### B. 数据库与中间件扩展
```
├── 🗄️ 关系型数据库
│   ├── PostgreSQL
│   ├── MySQL/MariaDB
│   └── SQLite
├── 🍃 NoSQL 数据库
│   ├── MongoDB
│   ├── Redis
│   └── Elasticsearch
├── 📨 消息队列
│   ├── RabbitMQ
│   ├── Kafka
│   └── Redis Pub/Sub
└── 🔄 负载均衡
    ├── Nginx
    ├── Traefik
    └── HAProxy
```

#### C. 云平台与容器编排扩展
```
├── ☁️ 云平台支持
│   ├── AWS (ECR, ECS, Lambda)
│   ├── Google Cloud (GCR, GKE, Cloud Run)
│   ├── Azure (ACR, AKS, Container Instances)
│   └── 阿里云 (ACR, ACK, Serverless)
├── 🎭 容器编排
│   ├── Kubernetes
│   ├── Docker Swarm
│   └── Nomad
└── 🚀 Serverless
    ├── AWS Lambda
    ├── Vercel Functions
    └── Netlify Functions
```

## 3. 架构设计方案

### 3.1 精简模块化架构
```
DeployAgent/
├── 🏗️ builders/           # 构建器模块
│   ├── golang/            # Go 语言构建器
│   ├── python/            # Python 生态构建器
│   ├── java/              # Java 生态构建器
│   ├── node/              # Node.js 生态构建器
│   └── php/               # PHP 生态构建器
├── 🐳 dockerfiles/        # Dockerfile 模板
│   ├── golang/
│   ├── python/
│   ├── java/
│   ├── node/
│   └── php/
├── 📋 templates/          # 项目模板
│   ├── docker-compose/
│   └── scripts/
├── 🔍 detectors/          # 项目检测器
│   ├── detect-language.sh    # 语言检测
│   ├── detect-framework.sh   # 框架检测
│   └── detect-dependencies.sh # 依赖检测
└── 🛠️ core/              # 核心功能
    ├── config.sh          # 配置管理
    ├── logging.sh         # 日志系统
    └── utils.sh           # 工具函数
```

### 3.2 核心脚本重构

#### 主脚本 (`deploy-agent.sh`)
```bash
#!/bin/bash
# 通用部署代理 - 支持多语言构建部署
./deploy-agent.sh [OPTIONS] [PROJECT_PATH]

OPTIONS:
  -l, --language LANG     指定项目语言 (auto|golang|python|java|node|php)
  -f, --framework FRAME  指定框架 (auto|gin|fastapi|spring|nestjs|laravel)
  -t, --type TYPE        指定项目类型 (web|api|cli|worker)
  -p, --port PORT        指定应用端口 (默认: 8080)
  -c, --config FILE      使用配置文件
  --init                 初始化项目配置
  --dry-run              仅显示将要执行的操作
  --force                强制覆盖现有文件
```

#### 项目检测脚本 (`detect-project.sh`)
```bash
# 自动检测项目语言、框架、包管理器
./detect-project.sh [PROJECT_PATH]

输出:
{
  "language": "python",
  "framework": "fastapi",
  "package_manager": "pip",
  "build_tool": "poetry",
  "dependencies": [...],
  "recommended_dockerfile": "python/fastapi.Dockerfile"
}
```

## 4. 实施阶段规划

### 阶段 1: 基础重构 (1-2周)
- [ ] 重构现有代码为模块化架构
- [ ] 实现项目自动检测系统
- [ ] 创建统一的配置管理系统
- [ ] 建立插件式构建器架构

### 阶段 2: Go 语言支持 (3-5天)
- [ ] Go modules 检测
- [ ] Gin/Echo/Fiber 框架支持
- [ ] Go 标准库 HTTP 服务支持
- [ ] 跨平台编译支持

### 阶段 3: Python 生态支持 (3-5天)
- [ ] FastAPI 支持
- [ ] Django 支持
- [ ] Flask 支持
- [ ] Python 依赖管理 (pip, poetry, pipenv)

### 阶段 4: Java 生态支持 (5-7天)
- [ ] Spring Boot 支持
- [ ] Maven 项目支持
- [ ] Gradle 项目支持
- [ ] 多版本 JDK 支持

### 阶段 5: PHP 支持 (3-5天)
- [ ] Laravel 支持
- [ ] Symfony 支持
- [ ] Composer 依赖管理
- [ ] PHP-FPM + Nginx 配置

### 阶段 6: 完善和优化 (3-5天)
- [ ] 跨语言项目检测优化
- [ ] 统一配置文件格式
- [ ] 错误处理和回滚机制
- [ ] 文档和示例完善

## 5. 配置文件扩展

### 通用配置 (`deploy-agent.config`)
```bash
# DeployAgent 通用配置文件

# 项目基本信息
PROJECT_LANGUAGE="auto"           # auto, golang, python, java, node, php
PROJECT_FRAMEWORK="auto"          # auto, gin, fastapi, spring, nestjs, laravel
PROJECT_NAME="my-app"
PROJECT_VERSION="1.0.0"

# 构建配置
BUILD_TOOL="auto"                 # auto, npm, yarn, pnpm, pip, poetry, maven, gradle, go mod, composer
BUILD_COMMAND="auto"              # 自动检测或自定义
BUILD_ARGS=""                     # 额外构建参数

# Docker 配置
DOCKER_REGISTRY=""                # 私有镜像仓库
DOCKER_TAG_STRATEGY="timestamp"   # timestamp, version, git-hash
DOCKER_PLATFORM="linux/amd64"    # 目标平台

# 部署配置
DEPLOY_PLATFORM="docker"          # docker, kubernetes, aws, gcp, azure
DEPLOY_ENVIRONMENT="production"    # development, staging, production
REMOTE_HOST=""                    # 远程服务器地址
REMOTE_USER=""                    # SSH 用户名
REMOTE_PATH=""                    # 部署路径

# 高级配置
ENABLE_MONITORING=true            # 启用监控
ENABLE_LOGGING=true               # 启用日志收集
ROLLBACK_ON_FAILURE=true          # 失败时自动回滚
HEALTH_CHECK_URL=""               # 健康检查地址
NOTIFICATION_WEBHOOK=""           # 通知 webhook
```

## 6. 开发优先级建议

1. **本周目标**: 基础架构重构和 Go 语言支持
2. **下周目标**: Python 和 Java 支持
3. **第三周**: PHP 支持和整体优化
4. **后续**: 文档完善和示例项目

## 7. 预期成果

完成后的 DeployAgent 将支持：
- **5种主流语言**: Go, Python, Java, Node.js, PHP  
- **15+框架**: Gin/Echo, FastAPI/Django/Flask, Spring Boot, NestJS/Express, Laravel/Symfony
- **统一的配置和部署流程**
- **自动项目检测和智能构建**
- **完善的错误处理和回滚机制**

这将使 DeployAgent 成为一个实用、高效的多语言构建部署工具。