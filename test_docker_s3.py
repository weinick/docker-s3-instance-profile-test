#!/usr/bin/env python3
import boto3
from botocore.exceptions import ClientError
import requests
import json
import os
import tempfile
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
        
        # 测试文件上传和下载
        print("\n4. 测试 S3 文件上传和下载...")
        test_file_operations(s3_client)
        
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

def test_file_operations(s3_client):
    """测试 S3 文件上传和下载操作"""
    bucket_name = 'share-something-only-from-here'
    test_file_name = f'docker-test-{datetime.now().strftime("%Y%m%d-%H%M%S")}.txt'
    local_test_file = f'/tmp/{test_file_name}'
    download_file = f'/tmp/downloaded-{test_file_name}'
    
    try:
        # 步骤 1: 创建测试文件
        print(f"   📝 创建测试文件: {local_test_file}")
        test_content = f"""Docker S3 测试文件
创建时间: {datetime.now()}
测试目的: 验证 Docker 容器中的 S3 上传下载功能
容器ID: {os.environ.get('HOSTNAME', 'unknown')}
测试桶: {bucket_name}
"""
        
        with open(local_test_file, 'w', encoding='utf-8') as f:
            f.write(test_content)
        
        file_size = os.path.getsize(local_test_file)
        print(f"   ✅ 测试文件创建成功，大小: {file_size} 字节")
        
        # 步骤 2: 上传文件到 S3
        print(f"   📤 上传文件到 S3 桶: {bucket_name}")
        try:
            s3_client.upload_file(
                local_test_file, 
                bucket_name, 
                test_file_name,
                ExtraArgs={'ServerSideEncryption': 'AES256'}
            )
            print(f"   ✅ 文件上传成功: s3://{bucket_name}/{test_file_name}")
            
            # 验证文件是否存在
            response = s3_client.head_object(Bucket=bucket_name, Key=test_file_name)
            print(f"   📊 上传文件信息:")
            print(f"      - 大小: {response['ContentLength']} 字节")
            print(f"      - 最后修改: {response['LastModified']}")
            print(f"      - ETag: {response['ETag']}")
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == 'NoSuchBucket':
                print(f"   ❌ 桶不存在: {bucket_name}")
                return
            elif error_code == 'AccessDenied':
                print(f"   ❌ 访问被拒绝，检查权限设置")
                return
            else:
                print(f"   ❌ 上传失败: {error_code} - {e.response['Error']['Message']}")
                return
        
        # 步骤 3: 下载文件
        print(f"   📥 从 S3 下载文件到: {download_file}")
        try:
            s3_client.download_file(bucket_name, test_file_name, download_file)
            
            # 验证下载的文件
            if os.path.exists(download_file):
                download_size = os.path.getsize(download_file)
                print(f"   ✅ 文件下载成功，大小: {download_size} 字节")
                
                # 比较文件内容
                with open(local_test_file, 'r', encoding='utf-8') as f1, \
                     open(download_file, 'r', encoding='utf-8') as f2:
                    original_content = f1.read()
                    downloaded_content = f2.read()
                    
                    if original_content == downloaded_content:
                        print(f"   ✅ 文件内容验证成功，上传下载完整")
                    else:
                        print(f"   ⚠️  文件内容不匹配")
            else:
                print(f"   ❌ 下载文件不存在")
                
        except ClientError as e:
            print(f"   ❌ 下载失败: {e.response['Error']['Code']} - {e.response['Error']['Message']}")
        
        # 步骤 4: 保留测试文件
        print(f"   📁 保留测试文件...")
        try:
            # 保留 S3 中的文件
            print(f"   ✅ S3 文件已保留: s3://{bucket_name}/{test_file_name}")
            
            # 保留下载的文件，删除原始测试文件
            if os.path.exists(local_test_file):
                os.remove(local_test_file)
                print(f"   ✅ 原始测试文件已删除: {local_test_file}")
            
            if os.path.exists(download_file):
                print(f"   ✅ 下载文件已保留: {download_file}")
            
            print(f"   📋 文件保留总结:")
            print(f"      - S3 文件: s3://{bucket_name}/{test_file_name}")
            print(f"      - 本地文件: {download_file}")
                    
        except Exception as e:
            print(f"   ⚠️  处理文件时出错: {e}")
            
    except Exception as e:
        print(f"   ❌ 文件操作测试失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_docker_s3()
