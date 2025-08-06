FROM python:3.9-slim

WORKDIR /app

# 安装 boto3 和 requests
RUN pip install boto3 requests

# 复制测试脚本
COPY test_docker_s3.py .

# 运行测试
CMD ["python", "test_docker_s3.py"]
