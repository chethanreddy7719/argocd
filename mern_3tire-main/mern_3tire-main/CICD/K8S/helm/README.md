<p align="center">
  <img src="https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white" alt="Jenkins"/>
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" alt="Kubernetes"/>
  <img src="https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white" alt="Helm"/>
  <img src="https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white" alt="ArgoCD"/>
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/>
  <img src="https://img.shields.io/badge/Trivy-1904DA?style=for-the-badge&logo=aqua&logoColor=white" alt="Trivy"/>
</p>

# Jenkins CI/CD Pipeline — K8s Deployment via Helm + ArgoCD (GitOps)

A production-grade Jenkins declarative pipeline that builds, scans, and pushes the backend Docker image, then **updates the Helm chart values in Git** — triggering **ArgoCD** to auto-sync the change to Kubernetes clusters. This is the **GitOps approach** — Git is the single source of truth, ArgoCD is the delivery mechanism.

> [!NOTE]
> Think of it as a two-phase delivery system. **Phase 1 (Jenkins):** build, scan, push — same as the Docker Build pipeline. **Phase 2 (GitOps):** Jenkins updates `values.yaml` in Git with the new image tag → ArgoCD detects the commit → auto-syncs to K8s clusters. Jenkins never talks to K8s directly.

---

## Pipeline Overview

<p align="center">
  <img src="./pipeline-diagram.svg" alt="GitOps CI/CD Pipeline Overview" width="100%"/>
</p>

**`Stage 1` — CHECKOUT** &ensp; ![Git](https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white)

- Pulls the full monorepo — application code + Helm charts live in the same repo
- Triggered by **GitHub webhook** on push to `main`

**`Stage 2` — SONARQUBE ANALYSIS** &ensp; ![SonarQube](https://img.shields.io/badge/SAST-4E9BCD?style=flat-square&logo=sonarqube&logoColor=white)

- Runs **SAST** on the backend source code — bugs, code smells, security hotspots
- Quality gate — bad code never gets built into a container

**`Stage 3` — DOCKER BUILD** &ensp; ![Docker](https://img.shields.io/badge/Build-2496ED?style=flat-square&logo=docker&logoColor=white)

- Builds the backend image tagged with Jenkins `BUILD_NUMBER` for traceability
- `--no-cache` for reproducible, deterministic builds

**`Stage 4` — TRIVY SCAN** &ensp; ![Security](https://img.shields.io/badge/CVE_Scan-cc0000?style=flat-square&logo=aqua&logoColor=white)

- Two-pass CVE scan — Pass 1 logs LOW-HIGH, Pass 2 **fails the build** on CRITICAL
- Shift-left security before the image reaches any registry or cluster

**`Stage 5` — PUSH IMAGE** &ensp; ![Registry](https://img.shields.io/badge/Push-2496ED?style=flat-square&logo=docker&logoColor=white)

- Pushes verified image to Docker Hub with **immutable tag** (`BUILD_NUMBER`) + rolling `latest`
- Only images passing both quality and security gates arrive here

**`Stage 6` — UPDATE GITOPS REPO** &ensp; ![GitOps](https://img.shields.io/badge/GitOps-F05032?style=flat-square&logo=git&logoColor=white)

- Updates the Helm chart's `values.yaml` with the new image tag using `sed`
- Commits and pushes the change back to `main` — this triggers ArgoCD to sync
- ArgoCD (with **auto-sync + prune + selfHeal**) applies the new Helm chart to the cluster

**`Post-Build` — CLEANUP** &ensp; ![Cleanup](https://img.shields.io/badge/Cleanup-grey?style=flat-square&logo=jenkins&logoColor=white)

- Removes local Docker image and wipes workspace
- Runs on every build regardless of outcome

<br>

<details>
<summary><b>How I'd Explain This in an Interview</b> (click to expand)</summary>
<br>

> *"We use a GitOps approach for Kubernetes deployments. Jenkins handles the CI side — code checkout, SonarQube analysis, Docker build, Trivy CVE scanning, and image push to Docker Hub. After the image is pushed, Jenkins updates the Helm chart's values.yaml with the new image tag and commits it back to Git. That's where Jenkins' job ends. ArgoCD watches the Git repository and detects the values change. Since we have auto-sync enabled with prune and selfHeal, ArgoCD automatically renders the Helm chart with the new values and applies it to the K8s cluster. The key benefit is Git becomes the single source of truth — every deployment is auditable as a Git commit, and if something goes wrong, we can git revert and ArgoCD will roll back the cluster state."*

</details>

---

## CI/CD Setup

### Prerequisites

| Tool | Purpose | Install On |
|:-----|:--------|:-----------|
| ![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=flat-square&logo=jenkins&logoColor=white) **Jenkins** | CI/CD orchestrator | Server / VM / Docker |
| ![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white) **Docker** | Container runtime | Jenkins server |
| ![SonarQube](https://img.shields.io/badge/SonarQube-4E9BCD?style=flat-square&logo=sonarqube&logoColor=white) **SonarQube** | Static code analysis | Separate server / container |
| ![Trivy](https://img.shields.io/badge/Trivy-1904DA?style=flat-square&logo=aqua&logoColor=white) **Trivy** | Container vulnerability scanner | Jenkins server |
| **sonar-scanner** | CLI to push analysis to SonarQube | Jenkins server |
| ![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=flat-square&logo=argo&logoColor=white) **ArgoCD** | GitOps controller | K8s cluster |
| ![Helm](https://img.shields.io/badge/Helm-0F1689?style=flat-square&logo=helm&logoColor=white) **Helm** | K8s package manager | ArgoCD handles rendering |

> [!IMPORTANT]
> Jenkins does **not** need `kubectl` or `helm` installed — it never talks to K8s directly. ArgoCD handles the cluster deployment.

### 1. Run Jenkins (Docker)

```bash
docker run -d \
  --name jenkins \
  --restart=on-failure \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts-jdk21
```

### 2. Install Docker + Trivy + sonar-scanner inside Jenkins

```bash
# Docker CLI
docker exec -u root jenkins bash -c "
  apt-get update && apt-get install -y docker.io && usermod -aG docker jenkins
"
docker restart jenkins

# Trivy
docker exec -u root jenkins bash -c "
  apt-get install -y wget apt-transport-https gnupg lsb-release && \
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg && \
  echo 'deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main' | tee /etc/apt/sources.list.d/trivy.list && \
  apt-get update && apt-get install -y trivy
"

# SonarQube Scanner
docker exec -u root jenkins bash -c "
  wget -qO /tmp/sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip && \
  unzip /tmp/sonar-scanner.zip -d /opt && \
  ln -s /opt/sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner && \
  rm /tmp/sonar-scanner.zip
"
```

### 3. ArgoCD Setup on K8s Cluster

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

The ArgoCD Application manifest for the backend is at `k8s/ArgoCD/backend-app.yaml`:

```yaml
# Key configuration:
source:
  repoURL: https://github.com/jaintpharsha/mern_3tire.git
  targetRevision: main
  path: k8s/backend/backend-chart
  helm:
    valueFiles:
      - values.yaml
syncPolicy:
  automated:
    prune: true      # Remove resources no longer in Git
    selfHeal: true   # Fix any manual drift from Git state
```

### 4. Required Jenkins Plugins

> [!IMPORTANT]
> Install from **Manage Jenkins > Plugins > Available plugins**

| Plugin Name | Search Keyword | Purpose |
|:------------|:---------------|:--------|
| **Docker Pipeline** | `docker-workflow` | `docker.build()`, `docker.withRegistry()` |
| **Pipeline** | `workflow-aggregator` | Core declarative pipeline engine |
| **Git** | `git` | SCM checkout from GitHub |
| **SonarQube Scanner** | `sonar` | SonarQube integration |
| **Credentials Binding** | `credentials-binding` | `withCredentials()` for secrets |
| **Timestamper** | `timestamper` | Adds timestamps to console output |

### 5. Jenkins Credentials

> [!WARNING]
> Set these up **before** running the pipeline: **Manage Jenkins > Credentials > System > Global credentials**

| Credential ID | Type | What It Holds |
|:--------------|:-----|:--------------|
| `github` | Username with password | GitHub access (username + PAT) — used for checkout AND git push |
| `docker_hub` | Username with password | Docker Hub login credentials |
| `backend` | Secret text | SonarQube project token (`SONAR_TOKEN`) |

> [!NOTE]
> No `kubeconfig` needed — Jenkins never touches the K8s cluster. ArgoCD handles deployment.

---

## Stages — Detailed Breakdown

### Stage 1: CHECKOUT &ensp; ![Git](https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white)

```groovy
stage('CHECKOUT') {
    steps {
        checkout([
            $class: 'GitSCM',
            branches: [[name: '*/main']],
            userRemoteConfigs: [[
                credentialsId: 'github',
                url: "${GIT_REPO}"
            ]]
        ])
    }
}
```

**What's happening:** Pulls the full repo. Both the backend application code (for building) and the Helm chart values (for updating) live in this repo.

> [!TIP]
> **Interview note:** *"The monorepo approach means our CI pipeline can both build the app and update the deployment config in one job. The alternative is a separate GitOps repo — which is more common at scale but adds complexity."*

---

### Stage 2: SONARQUBE ANALYSIS &ensp; ![SonarQube](https://img.shields.io/badge/SAST-4E9BCD?style=flat-square&logo=sonarqube&logoColor=white)

```groovy
stage('SONARQUBE ANALYSIS') {
    steps {
        dir('./backend') {
            withCredentials([string(credentialsId: 'backend', variable: 'SONAR_TOKEN')]) {
                sh "sonar-scanner -Dsonar.host.url=${SONAR_HOST_URL}"
            }
        }
    }
}
```

**What's happening:** SAST analysis on the backend source code. Quality gate checks for bugs, code smells, security hotspots, and coverage thresholds.

---

### Stage 3: DOCKER BUILD &ensp; ![Docker](https://img.shields.io/badge/Build-2496ED?style=flat-square&logo=docker&logoColor=white)

```groovy
stage('DOCKER BUILD') {
    steps {
        script {
            dir('./backend') {
                backendImage = docker.build(
                    "${BACKEND_IMAGE}:${env.BUILD_NUMBER}",
                    "--no-cache -f ${DOCKERFILE} ."
                )
            }
        }
    }
}
```

**What's happening:** Fresh Docker image build with `BUILD_NUMBER` tag. The `--no-cache` flag ensures no stale layers.

---

### Stage 4: TRIVY SCAN &ensp; ![Security](https://img.shields.io/badge/CVE_Scan-cc0000?style=flat-square&logo=aqua&logoColor=white)

```groovy
stage('TRIVY SCAN') {
    steps {
        sh """
            trivy image \
                --severity LOW,MEDIUM,HIGH \
                --exit-code 0 \
                --format table \
                ${BACKEND_IMAGE}:${env.BUILD_NUMBER}
        """
        sh """
            trivy image \
                --severity CRITICAL \
                --exit-code 1 \
                --format table \
                ${BACKEND_IMAGE}:${env.BUILD_NUMBER}
        """
    }
}
```

**What's happening:** Two-pass vulnerability scan.

| Pass | Severity | Exit Code | Behaviour |
|:-----|:---------|:----------|:----------|
| **Pass 1** | LOW, MEDIUM, HIGH | `0` | Logs to console, **does not fail** |
| **Pass 2** | CRITICAL | `1` | **Fails the build** — image never gets pushed |

---

### Stage 5: PUSH IMAGE &ensp; ![Registry](https://img.shields.io/badge/Push-2496ED?style=flat-square&logo=docker&logoColor=white)

```groovy
stage('PUSH IMAGE') {
    steps {
        script {
            docker.withRegistry('https://registry.hub.docker.com', 'docker_hub') {
                backendImage.push("${env.BUILD_NUMBER}")
                backendImage.push('latest')
            }
        }
    }
}
```

**What's happening:** Pushes verified image with dual tags:

```diff
+ harshajain/backend:42       ← immutable tag (referenced in Helm values)
+ harshajain/backend:latest   ← rolling tag for dev convenience
```

---

### Stage 6: UPDATE GITOPS REPO &ensp; ![GitOps](https://img.shields.io/badge/GitOps-F05032?style=flat-square&logo=git&logoColor=white)

```groovy
stage('UPDATE GITOPS REPO') {
    steps {
        withCredentials([usernamePassword(credentialsId: 'github', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
            sh """
                sed -i 's|tag:.*|tag: "${env.BUILD_NUMBER}"|' ${HELM_VALUES}
            """
            sh """
                git config user.email "jenkins@ci.local"
                git config user.name "Jenkins CI"
                git add ${HELM_VALUES}
                git commit -m "ci: update backend image tag to ${env.BUILD_NUMBER}"
                git push https://${GIT_USER}:${GIT_PASS}@github.com/jaintpharsha/mern_3tire.git HEAD:main
            """
        }
    }
}
```

**What's happening:**

1. **`sed`** updates the image tag in `k8s/backend/backend-chart/values.yaml`
2. **`git commit + push`** pushes the change back to `main`
3. **ArgoCD** detects the new commit (via webhook or polling) and auto-syncs

> [!TIP]
> **Interview note:** *"This is where CI meets CD. Jenkins' job is done after the git push. ArgoCD takes over — it detects the values.yaml change, renders the Helm chart with the new image tag, and applies it to the cluster. The separation of concerns is key: Jenkins handles build/test/push, ArgoCD handles deploy. If something goes wrong, every deployment is a git commit — we can `git revert` and ArgoCD will roll back automatically."*

> [!WARNING]
> **Infinite loop prevention:** The Jenkins commit message starts with `ci:` — configure your webhook or Jenkinsfile to skip builds triggered by commits with this prefix. Otherwise, Jenkins' own commit will trigger another build.

---

### Post-Build: Cleanup

```groovy
post {
    always {
        sh "docker rmi ${BACKEND_IMAGE}:${env.BUILD_NUMBER} || true"
        cleanWs()
    }
}
```

---

## GitOps Architecture — How ArgoCD Fits

```
┌──────────────────────────────────────────────────────────────────┐
│                         GIT REPOSITORY                           │
│                                                                  │
│  backend/                    k8s/backend/backend-chart/          │
│  ├── src/                    ├── Chart.yaml                      │
│  ├── Dockerfile              ├── values.yaml  ← Jenkins updates  │
│  └── package.json            └── templates/                      │
│                                  ├── deployment.yaml             │
│        CI (Jenkins)              ├── service.yaml                │
│        Builds this ──────────►   ├── ingress.yaml                │
│                                  └── secrets.yaml                │
└──────────────────────────────────┬───────────────────────────────┘
                                   │
                            ArgoCD watches
                                   │
                                   ▼
                        ┌──────────────────┐
                        │   ArgoCD Server   │
                        │                  │
                        │  auto-sync: true │
                        │  prune: true     │
                        │  selfHeal: true  │
                        └────────┬─────────┘
                                 │
                      Helm render + kubectl apply
                                 │
                    ┌────────────┼────────────┐
                    ▼            ▼            ▼
              ┌──────────┐ ┌──────────┐ ┌──────────┐
              │ us-prod  │ │ us-prod2 │ │  stage   │
              │ cluster  │ │ cluster  │ │ cluster  │
              └──────────┘ └──────────┘ └──────────┘
```

### ArgoCD Sync Policies Explained

| Policy | What It Does |
|:-------|:-------------|
| **auto-sync** | ArgoCD automatically applies changes when Git state differs from cluster state |
| **prune** | Removes K8s resources that no longer exist in Git (prevents orphaned resources) |
| **selfHeal** | If someone manually changes something in the cluster, ArgoCD reverts it to match Git |

---

## Helm Chart — Backend Values

The Helm chart at `k8s/backend/backend-chart/` deploys:

| Resource | Configuration |
|:---------|:-------------|
| **Deployment** | 2 replicas, image: `harshajain/backend:{tag}`, port 3000 |
| **Service** | ClusterIP on port 3000 |
| **Ingress** | NGINX Ingress at `backend.acadcart.com` |
| **Secrets** | JWT secret + MongoDB credentials |

> [!TIP]
> **Interview note:** *"Helm acts as a templating engine. Instead of hardcoding values in manifests, we use `values.yaml` to parameterize them. Jenkins only updates the `tag` field — everything else (replicas, ports, ingress rules) stays the same. ArgoCD renders the templates with the new values and applies the diff to the cluster."*

---

## kubectl vs Helm+ArgoCD — Interview Comparison

| Aspect | kubectl (Imperative) | Helm + ArgoCD (GitOps) |
|:-------|:--------------------|:----------------------|
| **Who deploys?** | Jenkins talks to K8s API directly | ArgoCD watches Git and syncs |
| **Source of truth** | K8s cluster state | Git repository |
| **Audit trail** | Jenkins build logs only | Every deploy = a git commit |
| **Rollback** | `kubectl rollout undo` | `git revert` → ArgoCD auto-syncs |
| **Drift detection** | None | ArgoCD detects and self-heals |
| **Multi-cluster** | Need separate kubectl contexts | ArgoCD manages all clusters |
| **Complexity** | Simple — one tool | More setup (ArgoCD + Helm) |
| **Best for** | Dev/staging, small teams | Production, compliance, scale |

---

## Quick Reference — Interview Terminology

| Term | One-Liner |
|:-----|:----------|
| **GitOps** | Using Git as the single source of truth for declarative infrastructure and workloads |
| **ArgoCD** | Kubernetes-native GitOps controller — watches Git repos and syncs cluster state |
| **Helm** | Kubernetes package manager — templates manifests using `values.yaml` |
| **Self-Heal** | ArgoCD reverts any manual changes in the cluster to match Git state |
| **Prune** | ArgoCD removes K8s resources deleted from Git (prevents orphaned resources) |
| **Shift-Left** | Moving testing and security earlier in the development lifecycle |
| **SAST** | Static Application Security Testing — analyzing code without executing it |
| **CVE** | Common Vulnerabilities and Exposures — standardized vulnerability IDs |
| **Immutable Tag** | Docker tag that never changes (build number). ArgoCD references this for deploys |
| **Declarative Pipeline** | Jenkins pipeline using `pipeline {}` blocks — structured and version-controlled |

---

## Full Pipeline Flow — Interview Whiteboard Version

```
  Developer pushes code
         │
         ▼
  ┌─── JENKINS PIPELINE (CI) ─────────────────────────────────────────┐
  │                                                                    │
  │  [1] CHECKOUT ──▶ [2] SONARQUBE ──▶ [3] DOCKER BUILD             │
  │      (git pull)      (SAST scan)       (image create)             │
  │                         │                    │                     │
  │                    Quality Gate          ┌────▼─────┐              │
  │                    (pass/fail)           │ [4] TRIVY │             │
  │                                         │   SCAN    │             │
  │                                         └────┬─────┘              │
  │                                              │                     │
  │                                     Pass 1: Log LOW-HIGH          │
  │                                     Pass 2: Fail on CRITICAL      │
  │                                              │                     │
  │                                         ┌────▼─────┐              │
  │                                         │ [5] PUSH  │             │
  │                                         │   IMAGE   │             │
  │                                         └────┬─────┘              │
  │                                              │                     │
  │                                         ┌────▼───────┐            │
  │                                         │ [6] UPDATE  │            │
  │                                         │  GITOPS     │            │
  │                                         │  REPO       │            │
  │                                         └────┬───────┘            │
  │                                              │                     │
  │                               sed → git commit → git push         │
  │                                              │                     │
  │  POST: docker rmi (cleanup) + cleanWs()      │                     │
  └──────────────────────────────────────────────┘                     │
                                                                       │
  ┌─── ARGOCD (CD) ──────────────────────────────┐                     │
  │                                              │◄────────────────────┘
  │  Detects Git change (webhook / poll)         │
  │         │                                    │
  │         ▼                                    │
  │  Renders Helm chart with new values.yaml     │
  │         │                                    │
  │         ▼                                    │
  │  kubectl apply (diff-based)                  │
  │         │                                    │
  │    ┌────┴─────┬──────────┐                   │
  │    ▼          ▼          ▼                   │
  │  us-prod   us-prod2   stage                  │
  │  cluster   cluster    cluster                │
  │                                              │
  │  Auto-sync · Prune · Self-Heal              │
  └──────────────────────────────────────────────┘
```
