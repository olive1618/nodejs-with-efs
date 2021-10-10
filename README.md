# nodejs-with-efs

Attempt deploy a lambda with a nodeJS runtime to access node modules in EFS during runtime.

Node modules are built and then copied to S3. DataSync is then used to sync the node modules from S3 to EFS