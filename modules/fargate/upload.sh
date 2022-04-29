#!/bin/bash

SCRDIR=$(dirname "$0")
cd $SCRDIR

# Start Docker
# sudo service docker start
#sudo service docker status

REGION="us-west-2"
PROFILE="sandbox"
REPO_NAME="kempy-fargate-repo-us-west-2"
# Create Repo with Terraform First
# aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION --profile $PROFILE || aws ecr create-repository --repository-name ${REPO_NAME} --region $REGION --profile $PROFILE

DOCKER_IMAGE=`aws ecr describe-repositories --repository-names $REPO_NAME --query 'repositories[0].repositoryUri' --output text --region $REGION --profile $PROFILE`
ECR_URL=`echo $DOCKER_IMAGE | awk -F/ '{print $1}'`

echo $ECR_URL

# ECR Login
aws ecr get-login-password --region $REGION --profile $PROFILE | docker login --username AWS --password-stdin $ECR_URL

cd src
docker build -t $DOCKER_IMAGE .
docker push $DOCKER_IMAGE
cd ..




