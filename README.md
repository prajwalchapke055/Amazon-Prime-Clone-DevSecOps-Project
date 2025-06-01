# Amazon Prime Clone Deployment Project
![Pipeline Overview](https://github.com/user-attachments/assets/23463138-c112-4997-8631-63218dbf6e53)

---

## Project Overview
This project demonstrates deploying an Amazon Prime clone using a set of DevOps tools and practices. The primary tools include:

- **Terraform**: Infrastructure as Code (IaC) tool to create AWS infrastructure such as EC2 instances and EKS clusters.
- **GitHub**: Source code management.
- **Jenkins**: CI/CD automation tool.
- **SonarQube**: Code quality analysis and quality gate tool.
- **NPM**: Build tool for NodeJS.
- **Aqua Trivy**: Security vulnerability scanner.
- **Docker**: Containerization tool to create images.
- **AWS ECR**: Repository to store Docker images.
- **AWS EKS**: Container management platform.
- **ArgoCD**: Continuous deployment tool.
- **Prometheus & Grafana**: Monitoring and alerting tools.

---

## Pre-requisites
1. **AWS Account**: Ensure you have an AWS account. [Create an AWS Account](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html)
2. **AWS CLI**: Install AWS CLI on your local machine. [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3. **VS Code (Optional)**: Download and install VS Code as a code editor. [VS Code Download](https://code.visualstudio.com/download)
4. **Install Terraform in Windows**: Download and install Terraform in Windows [Terraform in Windows](https://learn.microsoft.com/en-us/azure/developer/terraform/get-started-windows-bash)

---

## Note For Developers

- This project is a Amazon Prime Clone. You can run the below commands to see the project on your local system.
- Hosted on Firebase at - https://prime-clone-2fcfe.web.app/ (Desktop View Only). For getting Data I have used TMDB API.

- For running the App locally you will have to generate your own API_Key and substitute in all requests files and App.js files.
- You can check out other ReactJs projects as well in other repositories deployed on firebase.

- Icons from Material UI library have been used. Link is - https://material-ui.com/components/material-icons/

### Technologies Used:
- ReactJS
- NodeJS
- MaterialUI for icons

### Note: Don't use it for any commercial purposes.

---

## Configuration
### AWS Setup
1. **IAM User**: Create an IAM user and generate the access and secret keys to configure your machine with AWS.
2. **Key Pair**: Create a key pair named `key` for accessing your EC2 instances.

---

## Infrastructure Setup Using Terraform
1. **Clone the Repository** (Open Command Prompt & run below):
   ```bash
   git clone https://github.com/prajwalchapke055/Amazon-Prime-Clone-DevSecOps-Project.git
   cd Amazon-Prime-Clone-DevSecOps-Project
   code .   # this command will open VS code in backend
   ```
2. **Initialize and Apply Terraform**:
   - Run the below commands to reduce the path displayed in VS Code terminal (Optional)
     ```bash
     code $PROFILE
     function prompt {"$PWD > "}
     function prompt {$(Get-Location -Leaf) + " > "}
     ```
   - Open `terraform_code/ec2_server/main.tf` in VS Code.
   - Run the following commands:
     ```bash
     aws configure
     terraform init
     terraform apply --auto-approve
     ```

This will create the EC2 instance, security groups, and install necessary tools like Jenkins, Docker, SonarQube, etc.

---

## SonarQube Configuration
1. **Login Credentials**: Use `admin` for both username and password.
2. **Generate SonarQube Token**:
   - Create a token under `Administration → Security → Users → Tokens`.
   - Save the token for integration with Jenkins.

---

## Jenkins Configuration
1. **Add Jenkins Credentials**:
   - Add the SonarQube token, AWS access key, and secret key in `Manage Jenkins → Credentials → System → Global credentials`.
2. **Install Required Plugins**:
   - Install plugins such as SonarQube Scanner, NodeJS, Docker, and Prometheus metrics under `Manage Jenkins → Plugins`.

3. **Global Tool Configuration**:
   - Set up tools like JDK 17, SonarQube Scanner, NodeJS, and Docker under `Manage Jenkins → Global Tool Configuration`.

---

## Pipeline Overview
### Pipeline Stages
1. **Git Checkout**: Clones the source code from GitHub.
2. **SonarQube Analysis**: Performs static code analysis.
3. **Quality Gate**: Ensures code quality standards.
4. **Install NPM Dependencies**: Installs NodeJS packages.
5. **Trivy Security Scan**: Scans the project for vulnerabilities.
6. **Docker Build**: Builds a Docker image for the project.
7. **Push to AWS ECR**: Tags and pushes the Docker image to ECR.
8. **Image Cleanup**: Deletes images from the Jenkins server to save space.

---

### Running Jenkins Pipeline
Create and run the build pipeline in Jenkins. The pipeline will build, analyze, and push the project Docker image to ECR.
Create a Jenkins pipeline by adding the following script:

---

### Build Pipeline

```groovy
pipeline {
    agent any

    parameters {
        string(name: 'ECR_REPO_NAME', defaultValue: 'amazon-prime', description: 'Enter repository name')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '123456789012', description: 'Enter AWS Account ID')
    }

    tools {
        jdk 'JDK17'
        nodejs 'NodeJS'
    }

    environment {
        SCANNER_HOME = tool 'SonarQube Scanner'
    }

    stages {
        stage('1. Git Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/prajwalchapke055/Amazon-Prime-Clone-DevSecOps-Project.git'
            }
        }

        stage('2. SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh """
                    ${SCANNER_HOME}/bin/sonar-scanner \
                    -Dsonar.projectName=amazon-prime \
                    -Dsonar.projectKey=amazon-prime
                    """
                }
            }
        }

        stage('3. Quality Gate') {
            steps {
                waitForQualityGate abortPipeline: true
            }
        }

        stage('4. Install npm') {
            steps {
                sh '''
                rm -rf node_modules package-lock.json
                npm install --legacy-peer-deps
                '''
            }
        }


        stage ('5. OWASP Dependency-Check') {
            steps {
                withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                dependencyCheck additionalArguments: '--scan ./', odcInstallation: 'dc'
            }
            dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
        }
    }


        stage('6. Trivy Scan & Report') {
            steps {
                script {
                    sh "trivy fs --format table -o trivy-fs-report.html . "
                }
            }
        }


        stage('7. Build, Push & Deploy Docker Container') {
            steps {
                withDockerRegistry(credentialsId: 'docker', url: 'https://index.docker.io/v1/') {
                    script {
                        def imageName = "prajwal055/${params.ECR_REPO_NAME}"
                        def fullImage = "${imageName}:latest"

                        sh "docker build -t ${params.ECR_REPO_NAME} ."
                        sh "docker push ${fullImage}"
                        // sh "docker rm -f amazon-prime || true"
                        // sh "docker run -d --rm --name amazon-prime -p 3000:3000 ${fullImage}"
                        }
                    }
                }
        }

        stage('8. Create ECR Repo') {
            steps {
                withCredentials([
                    string(credentialsId: 'access-key', variable: 'AWS_ACCESS_KEY'),
                    string(credentialsId: 'secret-key', variable: 'AWS_SECRET_KEY')
                ]) {
                    sh '''
                    aws configure set aws_access_key_id $AWS_ACCESS_KEY
                    aws configure set aws_secret_access_key $AWS_SECRET_KEY
                    aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region us-east-1 || \
                    aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region us-east-1
                    '''
                }
            }
        }

        stage('9. Login to ECR & Tag Image') {
            steps {
                withCredentials([
                    string(credentialsId: 'access-key', variable: 'AWS_ACCESS_KEY'),
                    string(credentialsId: 'secret-key', variable: 'AWS_SECRET_KEY')
                ]) {
                    sh '''
                    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
                    docker tag ${ECR_REPO_NAME}:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}:${BUILD_NUMBER}
                    docker tag ${ECR_REPO_NAME}:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}:latest
                    '''
                }
            }
        }

        stage('10. Push Image to ECR') {
            steps {
                withCredentials([
                    string(credentialsId: 'access-key', variable: 'AWS_ACCESS_KEY'),
                    string(credentialsId: 'secret-key', variable: 'AWS_SECRET_KEY')
                ]) {
                    sh '''
                    docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}:${BUILD_NUMBER}
                    docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}:latest
                    '''
                }
            }
        }

        stage('11. Cleanup Images') {
            steps {
                sh '''
                docker rmi ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}:${BUILD_NUMBER} || true
                docker rmi ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}:latest || true
                docker images
                '''
            }
        }
    }

  post {
    always {
        script {
            def jobName = env.JOB_NAME
            def buildNumber = env.BUILD_NUMBER
            def buildStatus = currentBuild.currentResult ?: 'UNKNOWN'
            def buildUser = currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause')[0]?.userId ?: 'GitHub Triggered'
            def bannerColor = buildStatus.toUpperCase() == 'SUCCESS' ? 'green' : 'red'

            def body = """<html>
                            <body>
                                <div style="border: 4px solid ${bannerColor}; padding: 10px;">
                                    <h2>${jobName} - Build #${buildNumber}</h2>
                                    <div style="background-color: ${bannerColor}; padding: 10px;">
                                        <h3 style="color: white;">Pipeline Status: ${buildStatus.toUpperCase()}</h3>
                                    </div>
                                    <p><strong>Started by:</strong> ${buildUser}</p>
                                    <p>Check the <a href="${env.BUILD_URL}">console output</a>.</p>
                                </div>
                            </body>
                          </html>"""

            emailext(
                subject: "Pipeline ${buildStatus}: ${jobName} #${buildNumber}",
                body: body,
                to: 'prajwalchapke742@gmail.com',
                from: 'jenkins@example.com',
                replyTo: 'jenkins@example.com',
                mimeType: 'text/html',
                attachmentsPattern: 'trivy-fs-report.html,dependency-check-report.xml,**/*.html,**/*txt,**/*.xml'
            )
        }
    }
}
```
---

## Continuous Deployment with ArgoCD
1. **Create EKS Cluster**: Use Terraform to create an EKS cluster and related resources.
2. **Deploy Amazon Prime Clone**: Use ArgoCD to deploy the application using Kubernetes YAML files.
3. **Monitoring Setup**: Install Prometheus and Grafana using Helm charts for monitoring the Kubernetes cluster.

### Deployment Pipeline
```groovy
pipeline {
    agent any

    environment {
        KUBECTL = '/usr/local/bin/kubectl'
    }

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'Enter your AWS region')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '123456789000', description: 'Enter your AWS account ID')
        string(name: 'ECR_REPO_NAME', defaultValue: 'amazon-prime', description: 'Enter ECR repository name')
        string(name: 'VERSION', defaultValue: 'latest', description: 'Enter image version tag')
        string(name: 'CLUSTER_NAME', defaultValue: 'amazon-prime-cluster', description: 'Enter your EKS cluster name')
    }

    stages {

        stage("1. Clone GitHub Repository") {
            steps {
                git branch: 'main', url: 'https://github.com/pandacloud1/DevopsProject2.git'
            }
        }

        stage("2. Login to EKS") {
            steps {
                script {
                    withCredentials([
                        string(credentialsId: 'access-key', variable: 'AWS_ACCESS_KEY'),
                        string(credentialsId: 'secret-key', variable: 'AWS_SECRET_KEY')
                    ]) {
                        sh """
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY
                        aws configure set aws_secret_access_key $AWS_SECRET_KEY
                        aws configure set region ${params.AWS_REGION}
                        aws eks --region ${params.AWS_REGION} update-kubeconfig --name ${params.CLUSTER_NAME}
                        """
                    }
                }
            }
        }

        stage("3. Configure Prometheus & Grafana") {
            steps {
                script {
                    sh """
                    helm repo add stable https://charts.helm.sh/stable || true
                    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true

                    if kubectl get namespace prometheus > /dev/null 2>&1; then
                        helm upgrade stable prometheus-community/kube-prometheus-stack -n prometheus
                    else
                        kubectl create namespace prometheus
                        helm install stable prometheus-community/kube-prometheus-stack -n prometheus
                    fi

                    kubectl patch svc stable-kube-prometheus-sta-prometheus -n prometheus -p '{"spec": {"type": "LoadBalancer"}}'
                    kubectl patch svc stable-grafana -n prometheus -p '{"spec": {"type": "LoadBalancer"}}'
                    """
                }
            }
        }

        stage("4. Configure ArgoCD") {
            steps {
                script {
                    sh """
                    kubectl create namespace argocd || true
                    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
                    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
                    """
                }
            }
        }

        stage("5. Update Image in manifest.yml") {
            steps {
                script {
                    def IMAGE = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/${params.ECR_REPO_NAME}:${params.VERSION}"
                    sh "sed -i 's|image: .*|image: ${IMAGE}|' k8s_files/manifest.yml"
                }
            }
        }

        stage("6. Deploy Application to EKS") {
            steps {
                script {
                    // Apply single manifest
                    sh "kubectl apply -f k8s_files/manifest.yml"
                }
            }
        }
    }
}
```

---

## Screenshots of Website

![Screenshot (288)](https://github.com/user-attachments/assets/934be741-4a8a-4ddd-936e-d7899fd33496)

![Screenshot (289)](https://github.com/user-attachments/assets/f9da10e6-04ad-45d8-81d2-d85df3141c1f)

---

## Cleanup
- Run cleanup pipelines to delete the resources such as load balancers, services, and deployment files.
- Use `terraform destroy` to remove the EKS cluster and other infrastructure.

### Cleanup Pipeline
```groovy
pipeline {
    agent any

    environment {
        KUBECTL = '/usr/local/bin/kubectl'
    }

    parameters {
        string(name: 'CLUSTER_NAME', defaultValue: 'amazon-prime-cluster', description: 'Enter your EKS cluster name')
    }

    stages {

        stage("1. Login to EKS") {
            steps {
                script {
                    withCredentials([string(credentialsId: 'access-key', variable: 'AWS_ACCESS_KEY'),
                                     string(credentialsId: 'secret-key', variable: 'AWS_SECRET_KEY')]) {
                        sh "aws eks --region us-east-1 update-kubeconfig --name ${params.CLUSTER_NAME}"
                    }
                }
            }
        }
        
        stage('2. Cleanup K8s Resources') {
            steps {
                script {
                    // Step 1: Delete services and deployments
                    sh 'kubectl delete svc kubernetes || true'
                    sh 'kubectl delete deploy pandacloud-app || true'
                    sh 'kubectl delete svc pandacloud-app || true'

                    // Step 2: Delete ArgoCD installation and namespace
                    sh 'kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || true'
                    sh 'kubectl delete namespace argocd || true'

                    // Step 3: List and uninstall Helm releases in prometheus namespace
                    sh 'helm list -n prometheus || true'
                    sh 'helm uninstall kube-stack -n prometheus || true'
                    
                    // Step 4: Delete prometheus namespace
                    sh 'kubectl delete namespace prometheus || true'

                    // Step 5: Remove Helm repositories
                    sh 'helm repo remove stable || true'
                    sh 'helm repo remove prometheus-community || true'
                }
            }
        }
		
        stage('3. Delete ECR Repository and KMS Keys') {
            steps {
                script {
                    // Step 1: Delete ECR Repository
                    sh '''
                    aws ecr delete-repository --repository-name amazon-prime --region us-east-1 --force
                    '''

                    // Step 2: Delete KMS Keys
                    sh '''
                    for key in $(aws kms list-keys --region us-east-1 --query "Keys[*].KeyId" --output text); do
                        aws kms disable-key --key-id $key --region us-east-1
                        aws kms schedule-key-deletion --key-id $key --pending-window-in-days 7 --region us-east-1
                    done
                    '''
                }
            }
        }		
		
    }
}
```

---

## Additional Information
For further details, refer to the word document containing a complete write-up of the project.

- Contact Details: Email id => prajwalchapke055@gmail.com
- Hosted on Firebase at => https://prime-clone-2fcfe.web.app/

### Available Scripts
In this project directory, you can run:

```bash
npm install
```
This command installs all the required dependencies for running the App.

```bash
npm start
```
Runs the app in the development mode.

```bash 
Open http://localhost:3000 to view it in the browser. 
```

The page will reload if you make edits.
You will also see any lint errors in the console.

---
