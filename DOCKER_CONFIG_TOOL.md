# Docker 配置初始化工具

这个工具用于为前端项目快速生成 Docker 配置文件和相关脚本。

## 功能特性

- 自动检测项目类型（Next.js, React, Vue, Angular, Express.js）
- 生成适合项目类型的 Dockerfile
- 创建标准的目录结构（docker/, scripts/）
- 生成 docker-compose.yml 文件
- 创建构建和部署脚本
- 生成 Makefile 便于使用
- 创建 .dockerignore 文件
- 自动更新项目配置（如 Next.js 的 next.config.js）

## 使用方法

```bash
# 进入项目目录
cd your-project

# 运行初始化脚本
../init-docker-config.sh [项目名称]

# 或指定项目类型和端口
../init-docker-config.sh -t nextjs -p 3001 my-app
```

## 命令行参数

```bash
OPTIONS:
    -h, --help              显示帮助信息
    -t, --type TYPE         指定项目类型 (nextjs|react|vue|angular|express)
    -p, --port PORT         指定应用端口 (默认: 3000)
    --skip-scripts          跳过脚本文件创建
```

## 生成的文件结构

```
your-project/
├── docker/
│   └── docker-compose.yml
├── scripts/
│   ├── build.sh
│   └── deploy.sh
├── Dockerfile
├── Makefile
└── .dockerignore
```

## 使用生成的配置

1. 设置脚本执行权限:
   ```bash
   chmod +x scripts/*.sh
   ```

2. 构建和部署应用:
   ```bash
   # 使用 Makefile（推荐）
   make setup     # 一键构建并部署
   make build     # 仅构建
   make up        # 仅部署
   make logs      # 查看日志
   make down      # 停止应用
   make clean     # 清理容器和镜像

   # 或直接运行脚本
   ./scripts/build.sh     # 构建应用和镜像
   ./scripts/deploy.sh    # 部署应用
   ```

3. 访问应用:
   打开浏览器访问 http://localhost:3000（或指定的端口）