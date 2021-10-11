#!/bin/bash
set -eo pipefail
REGION=us-west-2
ACCOUNT_ID=1234567890
STACK='nodejs-with-efs'
artifact_bucket=node-with-efs
efs_mount_path="/mnt/efs"
lambda_function_name=node-with-efs


# Package and deploy
aws cloudformation package \
    --template-file template.yaml \
    --output-template-file packaged.yaml \
    --s3-bucket code-deploy \

aws cloudformation deploy \
    --template-file packaged.yaml \
    --stack-name $STACK \
    --s3-bucket code-deploy \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides S3DeployArtifactBucketName=$artifact_bucket EfsMountPath=$efs_mount_path


deploy_package_id=$(dd if=/dev/random bs=20 count=1 2>/dev/null | od -An -tx1 | tr -d ' \t\n')
deploy_package=lambda-$deploy_package_id-deploy.zip
cd  hello-world && \
    zip $deploy_package index.js && \
    aws s3 cp $deploy_package s3://$artifact_bucket/$deploy_package

aws lambda update-function-code \
    --function-name $lambda_function_name \
    --region $REGION \
    --s3-bucket $artifact_bucket \
    --s3-key $deploy_package

rm $deploy_package
cd ..