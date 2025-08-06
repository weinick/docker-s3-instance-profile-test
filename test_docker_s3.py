#!/usr/bin/env python3
import boto3
from botocore.exceptions import ClientError
import requests
import json
from datetime import datetime

def test_docker_s3():
    """测试 Docker 容器中的 S3 访问"""
    print("=" * 60)
    print("测试 Docker 容器中的 Instance Profile 访问 S3")
    print(f"测试时间: {datetime.now()}")
    print("=" * 60)
    
    try:
        # 测试 boto3 S3 访问
        print("1. 测试 boto3 S3 访问...")
        s3_client = boto3.client('s3', region_name='cn-north-1')
        response = s3_client.list_buckets()
        
        print(f"✅ Docker 容器中 S3 访问成功！")
        print(f"   共有 {len(response['Buckets'])} 个存储桶")
        
        if response['Buckets']:
            print("   存储桶列表（前3个）:")
            for bucket in response['Buckets'][:3]:
                print(f"     - {bucket['Name']}")
        
        # 测试元数据服务访问
        print("\n2. 测试元数据服务访问...")
        try:
            token_response = requests.put(
                'http://169.254.169.254/latest/api/token',
                headers={'X-aws-ec2-metadata-token-ttl-seconds': '21600'},
                timeout=5
            )
            
            if token_response.status_code == 200:
                token = token_response.text
                print("✅ 元数据服务访问成功")
                
                # 获取角色信息
                role_response = requests.get(
                    'http://169.254.169.254/latest/meta-data/iam/security-credentials/',
                    headers={'X-aws-ec2-metadata-token': token},
                    timeout=5
                )
                
                if role_response.status_code == 200:
                    role_name = role_response.text.strip()
                    print(f"✅ 角色名称: {role_name}")
            else:
                print(f"⚠️  元数据服务状态码: {token_response.status_code}")
        except Exception as e:
            print(f"⚠️  元数据服务测试: {e}")
        
        # 测试身份信息
        print("\n3. 测试身份信息...")
        sts_client = boto3.client('sts', region_name='cn-north-1')
        identity = sts_client.get_caller_identity()
        print(f"✅ 当前身份:")
        print(f"   账户ID: {identity['Account']}")
        print(f"   ARN: {identity['Arn']}")
        
        print("\n" + "=" * 60)
        print("🎉 Docker 容器测试成功！方法一在容器中也正常工作！")
        print("=" * 60)
        return True
        
    except Exception as e:
        print(f"❌ Docker 测试失败: {e}")
        print(f"错误类型: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    test_docker_s3()
