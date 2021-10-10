#!/bin/bash
set -eo pipefail
REGION=us-west-2
ACCOUNT_ID=1234567890
STACK='nodejs-with-efs'

# Create S3 bucket to hold build & deployment artifacts
artifact_bucket=nodejs-with-efs-artifacts
aws s3 mb s3://$artifact_bucket


# Package and deploy
lambda_function_name=hello-world-node-with-efs
aws cloudformation deploy \
    --template-file template.yaml \
    --stack-name $STACK \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides "ParameterKey=LambdaFunctionName,ParameterValue=$lambda_function_name ParamterKey=S3DeployArtifactBucketName,ParameterValue=$artifact_bucket"

deploy_package_id=$(dd if=/dev/random bs=20 count=1 2>/dev/null | od -An -tx1 | tr -d ' \t\n')
deploy_package=lambda-$deploy_package_id-deploy.zip
cd hello-world && \
    zip $deploy_package app.js package.json && \
aws s3 cp $deploy_package s3://$artifact_bucket/$deploy_package

aws lambda update-function-code \
    --function-name $lambda_function_name \
    --region $REGION \
    --s3-bucket $artifact_bucket \
    --s3-key $deploy_package


# Install node modules and then copy to S3
npm install lodash luxon --save
aws s3 sync ./node_modules s3://$artifact_bucket/node-modules
cd ..


# Create DataSync locations and task
efs_filesystem_arn=$(aws cloudformation list-exports --query "Exports[?Name=="$STACK-efs-filesystem-arn"].Value" --output text)
vpc_default_sg_id=$(aws cloudformation list-exports --query "Exports[?Name=="$STACK-vpc-sg-id"].Value" --output text)
vpc_subnet1_id=$(aws cloudformation list-exports --query "Exports[?Name=="$STACK-subnet-one-id"].Value" --output text)
s3_access_role_arn=$(aws cloudformation list-exports --query "Exports[?Name=="$STACK--ds-s3-access-role-arn"].Value" --output text)
data_sync_task_id=$(dd if=/dev/random bs=4 count=1 2>/dev/null | od -An -tx1 | tr -d ' \t\n')

ds_efs_location_arn=$(aws datasync create-location-efs \
    --subdirectory /mnt/efs/node/node_modules \
    --efs-filesystem-arn $efs_filesystem_arn \
    --ec2-config SecurityGroupArns="arn:aws:ec2:$REGION:$ACCOUNT_ID:security-group/$vpc_default_sg_id",SubnetArn="arn:aws:ec2:$REGION:$ACCOUNT_ID:subnet/$vpc_subnet1_id")

ds_s3_location_arn=$(aws datasync create-location-s3 \
    --subdirectory node-modules \
    --s3-bucket-arn "arn:aws:s3:::$artifact_bucket" \
    --s3-config "BucketAccessRoleArn=$s3_access_role_arn" )

aws datasync create-task \
    --source-location-arn $ds_s3_location_arn \
    --destination-location-arn $ds_efs_location_arn \
    --name datasync-s3-to-efs-$data_sync_task_id

aws datasync start-task-execution \
    --task-arn "arn:aws:datasync:$REGION:$ACCOUNT_ID:task/$data_sync_task_id"
