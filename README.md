# Brain Tasks App – AWS DevOps CI/CD Deployment

## Project Overview

This project demonstrates a complete **end-to-end DevOps CI/CD pipeline** for deploying a web application into a Kubernetes cluster on AWS.

The application is a static web application hosted using **Nginx inside Docker**, built automatically using AWS services, and deployed into **Amazon EKS (Elastic Kubernetes Service)** using CodePipeline.

The goal of this project is to implement a real-world DevOps workflow:

* Source Control
* Containerization
* Continuous Integration
* Continuous Deployment
* Kubernetes Orchestration

---

## Architecture

GitHub → CodePipeline → CodeBuild → Amazon ECR → Amazon EKS → AWS LoadBalancer → Public Internet

### Services Used

* GitHub (Source Code)
* Docker (Containerization)
* Amazon ECR (Container Registry)
* AWS CodeBuild (Build & Push Image)
* AWS CodePipeline (CI/CD Orchestration)
* Amazon EKS (Kubernetes Cluster)
* kubectl (Kubernetes Management)
* Nginx (Web Server)

---

## Application Details

* Application Type: Static Web Application
* Runtime: Nginx
* Container Port: 3000
* Deployment Platform: Kubernetes (EKS)

---

## Step-by-Step Implementation

### 1. Clone Repository

```bash
git clone https://github.com/<your-username>/Brain-Tasks-App.git
cd Brain-Tasks-App
```

---

### 2. Dockerization

A Docker image was created using Nginx to serve the static website.

**Dockerfile**

```dockerfile
FROM nginx:latest
COPY . /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
```

Build locally:

```bash
docker build -t brain-app .
docker run -p 3000:3000 brain-app
```

Application runs on:

```
http://localhost:3000
```

---

### 3. Push Docker Image to Amazon ECR

Create repository in ECR:

```
brain-tasks-repo
```

Authenticate Docker to ECR:

```bash
aws ecr get-login-password --region ap-south-1 \
| docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com
```

Tag and push:

```bash
docker tag brain-app:latest <account-id>.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-repo:latest
docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-repo:latest
```

---

### 4. Create EKS Cluster

```bash
eksctl create cluster --name brain-cluster --region ap-south-1
```

Configure kubectl:

```bash
aws eks --region ap-south-1 update-kubeconfig --name brain-cluster
kubectl get nodes
```

---

### 5. Kubernetes Deployment

**deployment.yml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: brain-tasks-app-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: brain-task
  template:
    metadata:
      labels:
        app: brain-task
    spec:
      containers:
      - name: brain-task
        image: <account-id>.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-repo:latest
        ports:
        - containerPort: 3000
```

**service.yml**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: brain-tasks-app-service
spec:
  type: LoadBalancer
  selector:
    app: brain-task
  ports:
  - port: 80
    targetPort: 3000
```

---

## Manual Kubernetes Deployment (Initial Verification)

Before automating the deployment using CodePipeline, the application was first deployed manually to verify the Kubernetes setup.

### Apply the manifests

```bash
kubectl apply -f deployment.yml
kubectl apply -f service.yml
```

### Verify deployment

Check if pods are created:

```bash
kubectl get pods
```

Expected output:

```
brain-tasks-app-deployment-xxxxx   Running
```

Check the service:

```bash
kubectl get svc
```

At first you will see:

```
brain-tasks-app-service   LoadBalancer   <pending>
```

Wait a few minutes and run again:

```
brain-tasks-app-service   LoadBalancer   a1b2c3d4e5.ap-south-1.elb.amazonaws.com
```

### Access the application

Open the LoadBalancer URL in the browser:

```
http://<load-balancer-url>
```

This confirms the Kubernetes cluster and networking are working correctly.

---

## Automated Deployment (CI/CD)

After verifying manual deployment, CI/CD was configured using AWS CodePipeline.
Now whenever code is pushed to GitHub:

1. CodePipeline detects the change
2. CodeBuild builds Docker image
3. Image pushed to Amazon ECR
4. EKS automatically updates deployment
5. Pods restart with the latest image
6. Application updates without manual intervention


### 6. CodeBuild (CI)

`buildspec.yml`

```yaml
version: 0.2

env:
  variables:
    ACCOUNT_ID: xxxxxxxxxxxx
    AWS_DEFAULT_REGION: your-default-region
    IMAGE_REPO_NAME: your-repo-name
    IMAGE_TAG: latest

phases:
  pre_build:
    commands:
      - ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com
  build:
    commands:
      - docker build -t brain-tasks-repo .
      - docker tag brain-tasks-repo:latest $ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-repo:latest
  post_build:
    commands:
      - docker push $ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-repo:latest
      - printf '[{"name":"brain-task","imageUri":"%s"}]' $ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-repo:latest > imagedefinitions.json

artifacts:
  files:
    - imagedefinitions.json
```
## AWS CodeBuild – Important Configuration Steps (Continuous Integration)

CodeBuild is used to automatically build the Docker image and push it to Amazon ECR whenever code is updated in GitHub.

### 1. Create CodeBuild Project

Go to **AWS Console → CodeBuild → Create Project**

**Project Settings**

* Project name: `brain-tasks-build`
* Source provider: GitHub (connected via CodePipeline)
* Environment type: Managed image
* Operating System: Ubuntu
* Runtime: Standard
* Image: `aws/codebuild/standard:7.0`
* Compute type: Small
* ✔ Enable **Privileged Mode** (required to run Docker inside CodeBuild)

---

### 2. IAM Permissions

The CodeBuild service role must have:

* AmazonEC2ContainerRegistryFullAccess (push images to ECR)
* S3 access (to download pipeline artifacts)

---

### 3. buildspec.yml

CodeBuild executes commands defined inside `buildspec.yml`.

Key operations performed:

1. Login to Amazon ECR
2. Build Docker image
3. Tag Docker image
4. Push image to ECR
5. Generate `imagedefinitions.json` for deployment

---

### 4. Build Process Flow

When the pipeline triggers:

* CodeBuild downloads source code
* Docker image is built
* Image is pushed to ECR
* Artifact is passed to CodePipeline Deploy stage

---

### 7. CodePipeline (CD)

Pipeline Stages:

1. Source – GitHub
2. Build – CodeBuild
3. Deploy – Amazon EKS

Whenever code is pushed to GitHub:

* Docker image builds automatically
* Image pushes to ECR
* Kubernetes deployment updates automatically

## AWS CodePipeline – Important Configuration Steps (Continuous Deployment)

CodePipeline automates the entire workflow from GitHub to Kubernetes deployment.

### Pipeline Stages

#### 1. Source Stage (GitHub)

* Provider: GitHub (via GitHub App connection)
* Repository: `Brain-Tasks-App`
* Branch: `main`
* Trigger: Automatically starts when code is pushed

Purpose:
Fetch latest source → send to build stage.

---

#### 2. Build Stage (CodeBuild)

* Provider: AWS CodeBuild
* Project: `brain-tasks-build`
* Uses `buildspec.yml`

Purpose:
Build Docker image and push to Amazon ECR.

---

#### 3. Deploy Stage (Amazon EKS)

* Deployment provider: Amazon EKS
* Cluster: `brain-cluster`
* Namespace: `default`
* Manifest files:

```
deployment.yml,service.yml
```

Purpose:
Apply Kubernetes manifests using `kubectl apply`.

---

### How Deployment Works

1. Code pushed to GitHub
2. CodePipeline detects change
3. CodeBuild builds Docker image
4. Image stored in Amazon ECR
5. EKS pulls new image
6. Kubernetes updates pods automatically
7. Application becomes live via LoadBalancer

---

### 8. Kubernetes RBAC Configuration

Grant pipeline access:
To allow CodePipeline to deploy to EKS:

1. Add CodePipeline IAM role to EKS Access Entry
2. Update `aws-auth` ConfigMap
3. Create Kubernetes ClusterRoleBinding:

```
kubectl create clusterrolebinding codepipeline-admin \
--clusterrole=cluster-admin \
--user=codepipeline
```

This grants Kubernetes admin permission to the pipeline.

---

### 9. Verify Deployment

Check pods:

```bash
kubectl get pods
```

Check service:

```bash
kubectl get svc
```

You will get a public URL:

```
http://<load-balancer-url>
```

---

## CI/CD Workflow

1. Developer pushes code to GitHub
2. CodePipeline triggers automatically
3. CodeBuild builds Docker image
4. Image pushed to ECR
5. EKS pulls new image
6. Kubernetes updates pods
7. Application becomes publicly accessible

---

## Result

The application is successfully deployed on AWS Kubernetes cluster and accessible via public LoadBalancer URL.

---

## Conclusion

This project demonstrates a real production-style DevOps pipeline using AWS services.
It automates build, containerization, and deployment using Kubernetes and ensures continuous delivery of application updates.

