#!/bin/bash

echo "=========================================="
echo "构建并保存 Docker 镜像"
echo "=========================================="

# 构建 Docker 镜像
echo "1. 构建 Docker 镜像..."
docker build -t s3-test:latest .

if [ $? -eq 0 ]; then
    echo "✅ Docker 镜像构建成功"
else
    echo "❌ Docker 镜像构建失败"
    exit 1
fi

# 保存 Docker 镜像为 tar 文件
echo "2. 保存 Docker 镜像为 tar 文件..."
docker save -o s3-test-image.tar s3-test:latest

if [ $? -eq 0 ]; then
    echo "✅ Docker 镜像保存成功: s3-test-image.tar"
    ls -lh s3-test-image.tar
else
    echo "❌ Docker 镜像保存失败"
    exit 1
fi

echo ""
echo "=========================================="
echo "镜像打包完成！"
echo "=========================================="
echo "下一步操作："
echo "1. 将 s3-test-image.tar 上传到 EC2 实例"
echo "2. 在 EC2 上运行: docker load -i s3-test-image.tar"
echo "3. 运行测试: docker run --rm s3-test:latest"
echo "=========================================="
