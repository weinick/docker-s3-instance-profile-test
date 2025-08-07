#!/bin/bash

# 显示使用方法
show_usage() {
    echo "使用方法: $0 <EC2_IP> [KEY_FILE]"
    echo ""
    echo "参数说明:"
    echo "  EC2_IP    - EC2 实例的 IP 地址 (必需)"
    echo "  KEY_FILE  - SSH 密钥文件路径 (可选，默认: your-key.pem)"
    echo ""
    echo "示例:"
    echo "  $0 YOUR_EC2_IP"
    echo "  $0 YOUR_EC2_IP ~/.ssh/my-key.pem"
    echo ""
    exit 1
}

# 检查参数
if [ $# -lt 1 ]; then
    echo "❌ 错误: 缺少必需的参数"
    show_usage
fi

# 配置变量
EC2_IP="$1"
KEY_FILE="${2:-your-key.pem}"  # 如果没有提供第二个参数，使用默认值
IMAGE_FILE="s3-test-image.tar"

echo "=========================================="
echo "上传 Docker 镜像到 EC2 实例"
echo "=========================================="

# 检查文件是否存在
if [ ! -f "$IMAGE_FILE" ]; then
    echo "❌ 错误: $IMAGE_FILE 文件不存在"
    echo "请先运行 ./build_and_save.sh 构建镜像"
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "❌ 错误: SSH 密钥文件 $KEY_FILE 不存在"
    echo "请修改脚本中的 KEY_FILE 变量为正确的密钥文件路径"
    exit 1
fi

echo "1. 上传 Docker 镜像文件到 EC2..."
scp -i "$KEY_FILE" "$IMAGE_FILE" ec2-user@$EC2_IP:~/

if [ $? -eq 0 ]; then
    echo "✅ 文件上传成功"
else
    echo "❌ 文件上传失败"
    exit 1
fi

echo ""
echo "2. 在 EC2 上加载 Docker 镜像..."
ssh -i "$KEY_FILE" ec2-user@$EC2_IP << 'EOF'
echo "加载 Docker 镜像..."
sudo docker load -i s3-test-image.tar

echo "验证镜像加载..."
sudo docker images | grep s3-test

echo "清理镜像文件..."
rm -f s3-test-image.tar

echo "Docker 镜像已准备就绪！"
EOF

if [ $? -eq 0 ]; then
    echo "✅ Docker 镜像在 EC2 上加载成功"
else
    echo "❌ Docker 镜像加载失败"
    exit 1
fi

echo ""
echo "=========================================="
echo "上传完成！"
echo "=========================================="
echo "现在您可以在 EC2 上运行测试："
echo "ssh -i $KEY_FILE ec2-user@$EC2_IP"
echo "sudo docker run --rm s3-test:latest"
echo "=========================================="
