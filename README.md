# Docker S3 Instance Profile 测试 - 本地打包方案

## 📋 概述
由于 EC2 实例无法访问 Docker Hub，我们在本地构建 Docker 镜像，然后传输到 EC2 进行测试。

## 🚀 操作步骤

### 步骤 1: 本地构建 Docker 镜像

在您的本地电脑上：

```bash
# 进入测试目录
cd /tmp/docker-s3-test

# 构建并保存 Docker 镜像
chmod +x build_and_save.sh
./build_and_save.sh
```

这将创建一个 `s3-test-image.tar` 文件。

### 步骤 2: 手动上传到 EC2

#### 方法 A: 使用 SCP 上传
```bash
# 替换 your-key.pem 为您的实际密钥文件路径
scp -i your-key.pem s3-test-image.tar ec2-user@52.81.92.36:~/
```

#### 方法 B: 使用自动化脚本
```bash
# 先编辑 upload_to_ec2.sh，修改 KEY_FILE 变量
chmod +x upload_to_ec2.sh
./upload_to_ec2.sh
```

### 步骤 3: 在 EC2 上加载并测试

SSH 连接到 EC2：
```bash
ssh -i your-key.pem ec2-user@52.81.92.36
```

在 EC2 上执行：
```bash
# 加载 Docker 镜像
sudo docker load -i s3-test-image.tar

# 验证镜像加载
sudo docker images | grep s3-test

# 运行测试（挂载主机的 /tmp 目录到容器的 /host-tmp）
sudo docker run --rm -v /tmp:/host-tmp s3-test:latest

# 检查主机上下载的文件
ls -la /tmp/download/

# 清理
rm -f s3-test-image.tar
```

### 故障排除

如果遇到挂载问题，可以先测试挂载是否正常：
```bash
# 测试挂载是否工作
sudo docker run --rm -v /tmp:/host-tmp s3-test:latest ls -la /host-tmp

# 如果挂载失败，可以不使用挂载运行（文件会保存在容器内）
sudo docker run --rm s3-test:latest
```

如果下载文件找不到，请检查：
```bash
# 1. 确认使用了正确的挂载参数
sudo docker run --rm -v /tmp:/host-tmp s3-test:latest

# 2. 检查主机 /tmp 目录权限
ls -la /tmp/

# 3. 手动创建 download 目录并设置权限
sudo mkdir -p /tmp/download
sudo chmod 755 /tmp/download

# 4. 运行后检查文件
ls -la /tmp/download/
```

## 📺 预期测试结果

成功时的显示：
```
============================================================
测试 Docker 容器中的 Instance Profile 访问 S3
测试时间: 2025-08-06 13:15:30.123456
============================================================

1. 测试 boto3 S3 访问...
✅ Docker 容器中 S3 访问成功！
   共有 90 个存储桶

   存储桶列表（前3个）:
     - ab2webfront
     - ai-customer-service-apiconstructllmbotdocumentsfc4-i1qr5xylunsj
     - ai-customer-service-apiconstructllmbotdocumentsfc4-ww2owsajcmay

2. 测试元数据服务访问...
✅ 元数据服务访问成功
✅ 角色名称: PVRE-SSMOnboardingRole-K4CRSMYV2BU9

3. 测试身份信息...
✅ 当前身份:
   账户ID: 994626867605
   ARN: arn:aws-cn:sts::994626867605:assumed-role/PVRE-SSMOnboardingRole-K4CRSMYV2BU9/i-07f41015322e2403c

4. 测试 S3 文件上传和下载...
   📝 创建测试文件: /tmp/docker-test-20250806-131530.txt
   ✅ 测试文件创建成功，大小: 156 字节
   📤 上传文件到 S3 桶: share-something-only-from-here
   ✅ 文件上传成功: s3://share-something-only-from-here/docker-test-20250806-131530.txt
   📊 上传文件信息:
      - 大小: 156 字节
      - 最后修改: 2025-08-06 13:15:30+00:00
      - ETag: "d41d8cd98f00b204e9800998ecf8427e"
   📥 从 S3 下载文件到: /host-tmp/download/downloaded-docker-test-20250806-131530.txt
   ✅ 文件下载成功，大小: 156 字节
   ✅ 文件内容验证成功，上传下载完整
   📁 保留测试文件...
   ✅ S3 文件已保留: s3://share-something-only-from-here/docker-test-20250806-131530.txt
   ✅ 原始测试文件已删除: /tmp/docker-test-20250806-131530.txt
   ✅ 下载文件已保留: /tmp/download/downloaded-docker-test-20250806-131530.txt
   📋 文件保留总结:
      - S3 文件: s3://share-something-only-from-here/docker-test-20250806-131530.txt
      - 本地文件: /tmp/download/downloaded-docker-test-20250806-131530.txt

============================================================
🎉 Docker 容器测试成功！方法一在容器中也正常工作！
============================================================
```

## 🔧 故障排除

### 如果遇到权限错误：
```bash
# 确保 ec2-user 在 docker 组中
sudo usermod -a -G docker ec2-user
# 重新登录或使用 sudo
```

### 如果遇到网络错误：
- 检查 EC2 安全组是否允许出站流量
- 确认实例可以访问元数据服务 (169.254.169.254)

### 如果 boto3 导入失败：
```bash
# 在 EC2 上安装 boto3（如果之前安装失败）
sudo yum install -y python3-pip
pip3 install --user boto3 requests
```

## 📁 文件说明

- `Dockerfile`: Docker 镜像构建文件
- `test_docker_s3.py`: Docker 容器内的测试脚本
- `build_and_save.sh`: 本地构建和保存镜像的脚本
- `upload_to_ec2.sh`: 自动上传到 EC2 的脚本
- `README.md`: 本说明文件
- `.dockerignore`: Docker 构建忽略文件

## 📥 下载文件说明

- 测试脚本会自动在主机的 `/tmp` 目录下创建 `download` 子目录（如果不存在）
- 通过 Docker 卷挂载 `-v /tmp:/host-tmp`，容器可以访问主机的 `/tmp` 目录
- 从 S3 下载的文件会保存到主机的 `/tmp/download/` 目录中
- 上传的临时文件保存在容器内的 `/tmp` 目录，测试完成后会自动清理
- 下载的文件会保留在主机的 `/tmp/download/` 目录中，方便查看测试结果

## 🎯 测试目标

这个测试将验证：
1. ✅ Docker 容器可以继承 EC2 的 Instance Profile
2. ✅ boto3 在容器中自动获取凭证
3. ✅ 容器可以访问元数据服务
4. ✅ S3 访问权限正常工作
5. ✅ S3 文件上传和下载功能
6. ✅ 文件完整性验证
7. ✅ 方法一（直接继承）的可行性
