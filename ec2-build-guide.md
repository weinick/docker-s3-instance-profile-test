# EC2 构建并推送到 ECR Public 指南

## 📋 前提条件
- EC2 实例需要有适当的 IAM 角色权限
- 网络连接良好的 EC2 实例
- 已安装 Docker 和 AWS CLI

## 🚀 步骤 1: 在 EC2 上准备环境

### 1.1 连接到 EC2
```bash
ssh -i your-key.pem ec2-user@your-ec2-ip
```

### 1.2 安装必要工具（如果尚未安装）
```bash
# 更新系统
sudo yum update -y

# 安装 Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# 安装 AWS CLI v2（如果需要）
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 安装 git
sudo yum install -y git

# 重新登录以应用 docker 组权限
exit
# 重新 SSH 连接
```

## 🚀 步骤 2: 克隆项目并构建镜像

### 2.1 克隆 GitHub 项目
```bash
git clone https://github.com/weinick/docker-s3-instance-profile-test.git
cd docker-s3-instance-profile-test
```

### 2.2 构建 Docker 镜像
```bash
# 构建镜像，使用适合 ECR 的标签
docker build -t s3-instance-profile-test .

# 验证镜像构建成功
docker images | grep s3-instance-profile-test
```

## 🚀 步骤 3: 创建 ECR Public 仓库

### 3.1 配置 AWS CLI（如果需要）
```bash
# 检查当前配置
aws sts get-caller-identity

# 如果需要配置（通常 EC2 使用 Instance Profile）
# aws configure
```

### 3.2 创建 ECR Public 仓库
```bash
# 创建公共仓库（注意：ECR Public 只在 us-east-1 可用）
aws ecr-public create-repository \
    --repository-name s3-instance-profile-test \
    --region us-east-1 \
    --catalog-data description="Docker S3 Instance Profile 测试镜像"
```

## 🚀 步骤 4: 推送镜像到 ECR Public

### 4.1 获取登录令牌并登录
```bash
# 获取 ECR Public 登录令牌
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
```

### 4.2 标记镜像
```bash
# 获取您的仓库 URI（替换 YOUR_ALIAS 为实际的别名）
# 仓库 URI 格式: public.ecr.aws/YOUR_ALIAS/s3-instance-profile-test

# 查看您的 ECR Public 仓库信息
aws ecr-public describe-repositories --region us-east-1

# 标记镜像（请替换 YOUR_ALIAS）
docker tag s3-instance-profile-test:latest public.ecr.aws/YOUR_ALIAS/s3-instance-profile-test:latest
docker tag s3-instance-profile-test:latest public.ecr.aws/YOUR_ALIAS/s3-instance-profile-test:v1.0
```

### 4.3 推送镜像
```bash
# 推送镜像到 ECR Public
docker push public.ecr.aws/YOUR_ALIAS/s3-instance-profile-test:latest
docker push public.ecr.aws/YOUR_ALIAS/s3-instance-profile-test:v1.0
```

## 🚀 步骤 5: 验证推送成功

### 5.1 验证镜像在 ECR Public 中
```bash
# 列出仓库中的镜像
aws ecr-public describe-images \
    --repository-name s3-instance-profile-test \
    --region us-east-1
```

### 5.2 测试拉取镜像
```bash
# 删除本地镜像
docker rmi s3-instance-profile-test:latest
docker rmi public.ecr.aws/YOUR_ALIAS/s3-instance-profile-test:latest

# 从 ECR Public 拉取镜像
docker pull public.ecr.aws/YOUR_ALIAS/s3-instance-profile-test:latest

# 运行测试
docker run --rm public.ecr.aws/YOUR_ALIAS/s3-instance-profile-test:latest
```

## 🔧 完整的自动化脚本

创建一个自动化脚本 `build-and-push-ecr.sh`：

```bash
#!/bin/bash

# 配置变量
REPOSITORY_NAME="s3-instance-profile-test"
IMAGE_TAG="latest"
VERSION_TAG="v1.0"
REGION="us-east-1"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 开始构建并推送到 ECR Public...${NC}"

# 步骤 1: 构建镜像
echo -e "${YELLOW}📦 构建 Docker 镜像...${NC}"
docker build -t ${REPOSITORY_NAME}:${IMAGE_TAG} .
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Docker 镜像构建失败${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker 镜像构建成功${NC}"

# 步骤 2: 获取 ECR Public 登录令牌
echo -e "${YELLOW}🔐 登录到 ECR Public...${NC}"
aws ecr-public get-login-password --region ${REGION} | docker login --username AWS --password-stdin public.ecr.aws
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ ECR Public 登录失败${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ECR Public 登录成功${NC}"

# 步骤 3: 获取仓库 URI
echo -e "${YELLOW}📋 获取仓库信息...${NC}"
REPOSITORY_URI=$(aws ecr-public describe-repositories --repository-names ${REPOSITORY_NAME} --region ${REGION} --query 'repositories[0].repositoryUri' --output text 2>/dev/null)

if [ "$REPOSITORY_URI" == "None" ] || [ -z "$REPOSITORY_URI" ]; then
    echo -e "${YELLOW}📝 仓库不存在，正在创建...${NC}"
    aws ecr-public create-repository \
        --repository-name ${REPOSITORY_NAME} \
        --region ${REGION} \
        --catalog-data description="Docker S3 Instance Profile 测试镜像"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ 创建仓库失败${NC}"
        exit 1
    fi
    
    # 重新获取仓库 URI
    REPOSITORY_URI=$(aws ecr-public describe-repositories --repository-names ${REPOSITORY_NAME} --region ${REGION} --query 'repositories[0].repositoryUri' --output text)
fi

echo -e "${GREEN}✅ 仓库 URI: ${REPOSITORY_URI}${NC}"

# 步骤 4: 标记镜像
echo -e "${YELLOW}🏷️  标记镜像...${NC}"
docker tag ${REPOSITORY_NAME}:${IMAGE_TAG} ${REPOSITORY_URI}:${IMAGE_TAG}
docker tag ${REPOSITORY_NAME}:${IMAGE_TAG} ${REPOSITORY_URI}:${VERSION_TAG}
echo -e "${GREEN}✅ 镜像标记完成${NC}"

# 步骤 5: 推送镜像
echo -e "${YELLOW}⬆️  推送镜像到 ECR Public...${NC}"
docker push ${REPOSITORY_URI}:${IMAGE_TAG}
docker push ${REPOSITORY_URI}:${VERSION_TAG}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}🎉 镜像推送成功！${NC}"
    echo -e "${GREEN}📍 镜像地址: ${REPOSITORY_URI}:${IMAGE_TAG}${NC}"
    echo -e "${GREEN}📍 版本标签: ${REPOSITORY_URI}:${VERSION_TAG}${NC}"
    
    # 显示拉取命令
    echo -e "${YELLOW}📋 使用以下命令拉取镜像:${NC}"
    echo -e "${GREEN}docker pull ${REPOSITORY_URI}:${IMAGE_TAG}${NC}"
else
    echo -e "${RED}❌ 镜像推送失败${NC}"
    exit 1
fi
```

## 🎯 使用自动化脚本

```bash
# 创建并运行自动化脚本
chmod +x build-and-push-ecr.sh
./build-and-push-ecr.sh
```

## 📋 所需的 IAM 权限

确保您的 EC2 Instance Profile 包含以下权限：

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr-public:GetAuthorizationToken",
                "ecr-public:BatchCheckLayerAvailability",
                "ecr-public:GetDownloadUrlForLayer",
                "ecr-public:BatchGetImage",
                "ecr-public:DescribeRepositories",
                "ecr-public:CreateRepository",
                "ecr-public:InitiateLayerUpload",
                "ecr-public:UploadLayerPart",
                "ecr-public:CompleteLayerUpload",
                "ecr-public:PutImage",
                "ecr-public:DescribeImages"
            ],
            "Resource": "*"
        }
    ]
}
```

## 🔍 故障排除

### 常见问题：

1. **权限错误**: 确保 EC2 Instance Profile 有足够的 ECR Public 权限
2. **网络问题**: 确保 EC2 可以访问 public.ecr.aws
3. **区域问题**: ECR Public 只在 us-east-1 区域可用
4. **Docker 权限**: 确保用户在 docker 组中

### 验证命令：
```bash
# 检查 AWS 身份
aws sts get-caller-identity

# 检查 Docker 状态
docker info

# 检查网络连接
curl -I https://public.ecr.aws
```
