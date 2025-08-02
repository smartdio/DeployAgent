# Next.js 项目自动部署工具

这是一个用于自动化构建和部署 Next.js 项目的 Bash 脚本工具。

## 文档

- [需求文档](DOC/requirements.md)
- [设计文档](DOC/design.md)
- [Docker 配置工具](DOCKER_CONFIG_TOOL.md)

## 功能特性

- 自动检测项目使用的包管理器 (yarn, npm, pnpm)
- 构建 Next.js 项目
- 创建 Docker 镜像
- 通过 SSH 上传镜像到远程服务器
- 在远程服务器上自动更新 Docker Compose 服务
- 失败时自动回滚到上一个版本
- 支持将执行日志保存到指定目录
- 支持通过配置文件简化部署命令

## 系统要求

- 本地环境需要安装 Docker
- 本地环境需要能够通过 SSH 连接到远程服务器
- 远程服务器需要安装 Docker 和 Docker Compose

## 安装

```bash
git clone <repository-url>
cd DeployAgent
chmod +x deploy.sh
```

## 使用方法

```bash
./deploy.sh [选项]

选项:
  -p, --project-dir DIR       项目目录路径
  -n, --project-name NAME     项目名称（用于镜像命名）
  -c, --build-command CMD     构建命令 (如: "yarn build")
  -h, --remote-host HOST      远程服务器地址 (user@host)
  -i, --image-dir DIR         远程服务器镜像目录
  -d, --compose-dir DIR       远程服务器 Docker Compose 目录
  -l, --log-dir DIR           日志保存目录
  -m, --package-manager PM    包管理器 (yarn|npm|pnpm) [可选]
  -f, --config-file FILE      配置文件路径
  --help                      显示帮助信息
```

### 示例

```bash
# 使用命令行参数
./deploy.sh -p "/path/to/nextjs-project" \
            -n "my-app" \
            -c "yarn build" \
            -h "user@example.com" \
            -i "/home/user/images" \
            -d "/home/user/compose" \
            -l "/var/log/deploy"

# 使用配置文件
./deploy.sh -f "./deploy.config"
```



## 项目要求

要使用此部署工具，您的 Next.js 项目需要满足以下要求：

1. 项目根目录必须包含 `Dockerfile`
2. 项目根目录必须包含 `package.json`
3. 远程服务器上需要有对应的 `docker-compose.yml` 文件

## Dockerfile 示例

```Dockerfile
# 使用官方 Node.js 运行时作为基础镜像
FROM node:18-alpine

# 设置工作目录
WORKDIR /app

# 复制 package 文件
COPY package*.json ./

# 安装依赖
RUN npm ci --only=production

# 复制应用代码
COPY . .

# 构建应用
RUN npm run build

# 暴露端口
EXPOSE 3000

# 启动应用
CMD ["npm", "start"]
```

## 配置文件

除了使用命令行参数，您还可以使用配置文件来指定部署参数。这种方式特别适合需要频繁部署多个不同项目的场景。

### 创建配置文件

复制示例配置文件并根据您的环境修改值：

```bash
cp deploy.config.example deploy.config
```

然后编辑 `deploy.config` 文件，设置适合您环境的值。

### 配置文件格式

配置文件是一个 Bash 脚本，包含以下变量：

```bash
# 项目目录路径
PROJECT_DIR="/path/to/your/nextjs/project"

# 项目名称（用于镜像命名）
PROJECT_NAME="my-nextjs-app"

# 构建命令
BUILD_COMMAND="yarn build"

# 远程服务器地址 (user@host)
REMOTE_HOST="user@server.com"

# 远程服务器镜像目录
REMOTE_IMAGE_DIR="/home/user/images"

# 远程服务器 Docker Compose 目录
REMOTE_COMPOSE_DIR="/home/user/compose"

# 包管理器 (yarn|npm|pnpm) - 可选，留空则自动检测
PACKAGE_MANAGER=""

# 日志保存目录 - 可选，默认不保存日志到文件
LOG_DIR="/var/log/deploy"
```

## Docker Compose 示例

您的远程服务器上需要有一个 `docker-compose.yml` 文件来管理服务。以下是一个示例：

```yaml
version: '3.8'
services:
  nextjs-app:
    image: nextjs-app:latest
    ports:
      - "3000:3000"
    restart: always
```

## 工作流程

1. 在本地执行项目构建命令
2. 使用项目中的 Dockerfile 构建 Docker 镜像
3. 将镜像保存为 tar 文件
4. 通过 SSH 将镜像上传到远程服务器
5. 在远程服务器上：
   - 停止当前服务
   - 卸载旧镜像
   - 加载新镜像
   - 启动服务
6. 如果新版本启动失败，自动回滚到上一个版本

## 故障排除

### SSH 连接问题

确保您可以通过 SSH 直接连接到远程服务器：

```bash
ssh user@host
```

### Docker 权限问题

如果遇到 Docker 权限问题，可能需要将当前用户添加到 docker 组：

```bash
sudo usermod -aG docker $USER
```

## 许可证

MIT