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
    
    # 显示在其他 EC2 上运行的命令
    echo -e "${YELLOW}📋 在其他 EC2 上运行测试:${NC}"
    echo -e "${GREEN}# 推荐方式（挂载主机 /tmp 目录，使用 :Z 解决 SELinux 权限问题）${NC}"
    echo -e "${GREEN}sudo docker run --rm -v /tmp:/host-tmp:Z \\${NC}"
    echo -e "${GREEN}  -e S3_BUCKET_NAME=your-actual-bucket-name \\${NC}"
    echo -e "${GREEN}  -e AWS_REGION=cn-north-1 \\${NC}"
    echo -e "${GREEN}  ${REPOSITORY_URI}:${IMAGE_TAG}${NC}"
    echo ""
    echo -e "${GREEN}# 或者使用命令行参数方式：${NC}"
    echo -e "${GREEN}sudo docker run --rm -v /tmp:/host-tmp:Z \\${NC}"
    echo -e "${GREEN}  ${REPOSITORY_URI}:${IMAGE_TAG} \\${NC}"
    echo -e "${GREEN}  your-actual-bucket-name cn-north-1${NC}"
    echo ""
    echo -e "${GREEN}# 然后查看下载的文件：${NC}"
    echo -e "${GREEN}ls -la /tmp/download/${NC}"
    echo -e "${GREEN}cat /tmp/download/downloaded-docker-test-*.txt${NC}"
    echo ""
    echo -e "${YELLOW}📋 备用方式（不使用挂载，文件保存在容器内）:${NC}"
    echo -e "${GREEN}sudo docker run --rm \\${NC}"
    echo -e "${GREEN}  -e S3_BUCKET_NAME=your-actual-bucket-name \\${NC}"
    echo -e "${GREEN}  -e AWS_REGION=cn-north-1 \\${NC}"
    echo -e "${GREEN}  ${REPOSITORY_URI}:${IMAGE_TAG}${NC}"
else
    echo -e "${RED}❌ 镜像推送失败${NC}"
    exit 1
fi
