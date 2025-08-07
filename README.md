# Docker S3 Instance Profile 测试 - 本地打包方案

## 📋 概述
由于 EC2 实例无法访问 Docker Hub，我们在本地构建 Docker 镜像，然后传输到 EC2 进行测试。

## ⚙️ 配置要求

在开始之前，您需要准备以下信息：

### 1. **S3 桶名称**
- 您需要有一个可以读写的 S3 桶
- 确保 EC2 实例的 IAM 角色有该桶的访问权限

### 2. **EC2 实例信息**
- EC2 实例的公网 IP 地址
- SSH 密钥文件路径
- 确保 EC2 实例已安装 Docker

### 3. **IAM 权限**
EC2 实例的 IAM 角色需要以下权限：
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::your-s3-bucket-name",
                "arn:aws:s3:::your-s3-bucket-name/*"
            ]
        }
    ]
}
```

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

### 步骤 2: 上传到 EC2

#### 方法 A: 使用自动化脚本（推荐）
```bash
# 使用脚本上传（需要提供 EC2 IP 地址）
chmod +x upload_to_ec2.sh
./upload_to_ec2.sh YOUR_EC2_IP [your-key.pem]

# 示例：
./upload_to_ec2.sh 52.81.92.36
./upload_to_ec2.sh 52.81.92.36 ~/.ssh/my-key.pem
```

#### 方法 B: 使用 SCP 手动上传
```bash
# 替换 your-key.pem 为您的实际密钥文件路径，YOUR_EC2_IP 为您的 EC2 实例 IP
scp -i your-key.pem s3-test-image.tar ec2-user@YOUR_EC2_IP:~/
```

### 步骤 3: 在 EC2 上加载并测试

SSH 连接到 EC2：
```bash
ssh -i your-key.pem ec2-user@YOUR_EC2_IP
```

在 EC2 上执行：
```bash
# 加载 Docker 镜像
sudo docker load -i s3-test-image.tar

# 验证镜像加载
sudo docker images | grep s3-test

# 运行测试（推荐使用 :Z 参数解决 SELinux 权限问题）
# 方法 1: 使用环境变量指定 S3 桶名和区域（推荐）
sudo docker run --rm -v /tmp:/host-tmp:Z -e S3_BUCKET_NAME=your-actual-bucket-name -e AWS_REGION=us-west-2 s3-test:latest

# 方法 2: 使用命令行参数指定 S3 桶名和区域
sudo docker run --rm -v /tmp:/host-tmp:Z s3-test:latest your-actual-bucket-name us-west-2

# 方法 3: 只指定桶名，使用默认区域
sudo docker run --rm -v /tmp:/host-tmp:Z s3-test:latest your-actual-bucket-name

# 方法 4: 使用默认桶名和区域（需要修改源码）
sudo docker run --rm -v /tmp:/host-tmp:Z s3-test:latest

# 检查主机上下载的文件
ls -la /tmp/download/

# 查看下载的文件内容
cat /tmp/download/downloaded-docker-test-*.txt

# 清理
rm -f s3-test-image.tar
```



## 🔧 配置说明

### S3 桶名配置

测试脚本支持三种方式指定 S3 桶名（按优先级排序）：

1. **命令行参数**（最高优先级）：
   ```bash
   sudo docker run --rm -v /tmp:/host-tmp:Z s3-test:latest your-actual-bucket-name
   ```

2. **环境变量**：
   ```bash
   sudo docker run --rm -v /tmp:/host-tmp:Z -e S3_BUCKET_NAME=your-actual-bucket-name s3-test:latest
   ```

3. **默认值**（最低优先级）：
   - 如果以上两种方式都没有指定，将使用默认值 `your-s3-bucket-name`
   - 脚本会显示警告信息，提醒您指定实际的桶名

### AWS 区域配置

测试脚本支持三种方式指定 AWS 区域（按优先级排序）：

1. **命令行参数**（最高优先级）：
   ```bash
   sudo docker run --rm -v /tmp:/host-tmp:Z s3-test:latest bucket-name region-name
   ```

2. **环境变量**：
   ```bash
   sudo docker run --rm -v /tmp:/host-tmp:Z -e AWS_REGION=us-west-2 s3-test:latest
   # 或者
   sudo docker run --rm -v /tmp:/host-tmp:Z -e AWS_DEFAULT_REGION=us-west-2 s3-test:latest
   ```

3. **默认值**（最低优先级）：
   - 如果以上两种方式都没有指定，将使用默认值 `us-east-1`
   - 脚本会显示警告信息，提醒您指定实际的区域

### 完整配置示例

```bash
# 方法 1: 使用命令行参数（推荐）
sudo docker run --rm -v /tmp:/host-tmp:Z s3-test:latest my-bucket us-west-2

# 方法 2: 使用环境变量
sudo docker run --rm -v /tmp:/host-tmp:Z \
  -e S3_BUCKET_NAME=my-bucket \
  -e AWS_REGION=us-west-2 \
  s3-test:latest

# 方法 3: 混合使用
sudo docker run --rm -v /tmp:/host-tmp:Z \
  -e AWS_REGION=us-west-2 \
  s3-test:latest my-bucket
```

### 脚本参数说明

#### upload_to_ec2.sh 脚本
```bash
./upload_to_ec2.sh <EC2_IP> [KEY_FILE]
```

**参数说明**：
- `EC2_IP`: EC2 实例的 IP 地址（必需）
- `KEY_FILE`: SSH 密钥文件路径（可选，默认: your-key.pem）

**使用示例**：
```bash
# 使用默认密钥文件
./upload_to_ec2.sh 52.81.92.36

# 指定密钥文件
./upload_to_ec2.sh 52.81.92.36 ~/.ssh/my-key.pem
```

### 故障排除

如果遇到挂载问题，可以先测试挂载是否正常：
```bash
# 测试挂载是否工作（推荐使用 :Z 参数）
sudo docker run --rm -v /tmp:/host-tmp:Z s3-test:latest ls -la /host-tmp

# 如果仍然有问题，尝试不同的挂载方式：
# 方法 1: 标准挂载
sudo docker run --rm -v /tmp:/host-tmp s3-test:latest

# 方法 2: SELinux 兼容挂载（推荐）
sudo docker run --rm -v /tmp:/host-tmp:Z s3-test:latest

# 方法 3: 如果挂载失败，不使用挂载（文件会保存在容器内）
sudo docker run --rm s3-test:latest
```

如果下载文件找不到，请检查：
```bash
# 1. 确认使用了正确的挂载参数（推荐使用 :Z）
sudo docker run --rm -v /tmp:/host-tmp:Z s3-test:latest

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

⚠️  警告: 使用默认桶名 'your-s3-bucket-name'
   请通过以下方式之一指定实际的 S3 桶名:
   1. 命令行参数: python test_docker_s3.py your-actual-bucket-name
   2. 环境变量: export S3_BUCKET_NAME=your-actual-bucket-name
   3. Docker 环境变量: docker run -e S3_BUCKET_NAME=your-actual-bucket-name ...

⚠️  警告: 使用默认区域 'us-east-1'
   请通过以下方式之一指定实际的 AWS 区域:
   1. 命令行参数: python test_docker_s3.py bucket-name region-name
   2. 环境变量: export AWS_REGION=your-region
   3. Docker 环境变量: docker run -e AWS_REGION=your-region ...

1. 测试 boto3 S3 访问...
✅ Docker 容器中 S3 访问成功！
   使用区域: us-east-1
   共有 90 个存储桶

   存储桶列表（前3个）:
     - ab2webfront
     - ai-customer-service-apiconstructllmbotdocumentsfc4-i1qr5xylunsj
     - ai-customer-service-apiconstructllmbotdocumentsfc4-ww2owsajcmay

2. 测试元数据服务访问...
✅ 元数据服务访问成功
✅ 角色名称: YOUR-INSTANCE-ROLE-NAME

3. 测试身份信息...
✅ 当前身份:
   账户ID: 123456789012
   ARN: arn:aws:sts::123456789012:assumed-role/YOUR-INSTANCE-ROLE-NAME/i-1234567890abcdef0

4. 测试 S3 文件上传和下载...
   🔍 检查挂载点: /host-tmp
   ✅ 挂载点存在，使用主机路径: /host-tmp/download
   ✅ 挂载点可写
   ✅ 下载目录创建成功: /host-tmp/download
   ✅ 下载目录验证存在: /host-tmp/download
   📁 下载文件路径: /host-tmp/download/downloaded-docker-test-xxx.txt
   📝 创建测试文件: /tmp/docker-test-20250806-131530.txt
   ✅ 测试文件创建成功，大小: 156 字节
   📤 上传文件到 S3 桶: your-s3-bucket-name
   ✅ 文件上传成功: s3://your-s3-bucket-name/docker-test-20250806-131530.txt
   📊 上传文件信息:
      - 大小: 156 字节
      - 最后修改: 2025-08-06 13:15:30+00:00
      - ETag: "d41d8cd98f00b204e9800998ecf8427e"
   📥 从 S3 下载文件到: /host-tmp/download/downloaded-docker-test-20250806-131530.txt
   ✅ S3 下载操作完成
   ✅ 文件下载成功，大小: 156 字节
   📍 文件位置: /host-tmp/download/downloaded-docker-test-20250806-131530.txt
   🏠 主机路径: /tmp/download/downloaded-docker-test-20250806-131530.txt
   💡 在主机上使用此命令查看: cat /tmp/download/downloaded-docker-test-20250806-131530.txt
   ✅ 文件下载成功，大小: 156 字节
   ✅ 文件内容验证成功，上传下载完整
   📁 保留测试文件...
   ✅ S3 文件已保留: s3://your-s3-bucket-name/docker-test-20250806-131530.txt
   ✅ 原始测试文件已删除: /tmp/docker-test-20250806-131530.txt
   ✅ 下载文件已保留: /tmp/download/downloaded-docker-test-20250806-131530.txt
   📋 文件保留总结:
      - S3 文件: s3://your-s3-bucket-name/docker-test-20250806-131530.txt
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
