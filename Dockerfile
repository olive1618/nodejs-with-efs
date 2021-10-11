FROM node:14-buster-slim

WORKDIR /lambda-build
ENV REGION="us-west-2"
ENV ACCOUNT_ID="12345"
ENV S3_BUCKET="dev-cf-image"

COPY hello-world/package-lock.json .
COPY hello-world/package.json .

# Install node modules and sync to S3
RUN npm install && \
    aws s3 sync node_modules s3://$S3_BUCKET/node-modules

# Create DataSync locations and task. Then start task
RUN ds_efs_location_arn=$(aws datasync create-location-efs \
        --subdirectory "/" \
        --efs-filesystem-arn "arn:aws:elasticfilesystem:${REGION}:${ACCOUNT_ID}:file-system/fs-abc" \
        --ec2-config SubnetArn="arn:aws:ec2:${REGION}:${ACCOUNT_ID}:subnet/subnet-123",SecurityGroupArns="arn:aws:ec2:${REGION}:${ACCOUNT_ID}:security-group/sg-456") \
    && \
    ds_s3_location_arn=$(aws datasync create-location-s3 \
        --subdirectory node-modules \
        --s3-bucket-arn "arn:aws:s3:::$S3_BUCKET" \
        --s3-config "BucketAccessRoleArn=arn:aws:iam::${ACCOUNT_ID}:role/nodejs-with-efs-DataSyncS3AccessRole" ) \
    && \
    aws datasync create-task \
        --source-location-arn $ds_s3_location_arn \
        --destination-location-arn $ds_efs_location_arn \
        --options PreserveDeletedFiles=REMOVE \
        --name "s3-node-modules-to-efs" \
    && \
    aws datasync start-task-execution \
        --task-arn "arn:aws:datasync:${REGION}:${ACCOUNT_ID}:task/task123"
