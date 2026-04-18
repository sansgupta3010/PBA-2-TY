// ──────────────────────────────────────────────────────────────
//  ClassSense AI — Jenkins Declarative CI/CD Pipeline
//  Stages: Checkout → Lint → Build → Push → Deploy → Verify
// ──────────────────────────────────────────────────────────────

pipeline {
    agent any

    environment {
        IMAGE_NAME   = 'classsense-ai'
        IMAGE_TAG    = "${env.BUILD_NUMBER ?: 'latest'}"
        REGISTRY     = credentials('docker-registry-url')
        DEPLOY_HOST  = credentials('deploy-ssh-host')
        DEPLOY_USER  = 'deploy'
        APP_PORT     = '80'
        CONTAINER    = 'classsense-webapp'
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 25, unit: 'MINUTES')
    }

    stages {

        // ── 1. CHECKOUT ────────────────────────────────────────
        stage('Checkout') {
            steps {
                echo '⬇  Pulling source code from repository...'
                checkout scm
                sh 'echo "Branch: ${GIT_BRANCH}" && echo "Commit: ${GIT_COMMIT}"'
            }
        }

        // ── 2. LINT / VALIDATE ─────────────────────────────────
        stage('Validate HTML Files') {
            steps {
                echo '🔍  Validating all required HTML files...'
                sh '''
                    echo "── Checking required files ──"
                    MISSING=0
                    for f in home.html about.html teacher.html index.html Dockerfile; do
                        if [ ! -f "$f" ]; then
                            echo "❌  MISSING: $f"
                            MISSING=1
                        else
                            echo "✔   Found:   $f"
                        fi
                    done

                    if [ $MISSING -eq 1 ]; then
                        echo "Build FAILED — required files are missing."
                        exit 1
                    fi

                    echo ""
                    echo "── Validating HTML structure ──"
                    for f in home.html about.html teacher.html index.html; do
                        if ! grep -q "</html>" "$f"; then
                            echo "❌  $f appears malformed (missing </html>)"
                            exit 1
                        fi
                        if ! grep -q "charset" "$f"; then
                            echo "⚠   $f missing charset meta tag"
                        fi
                        echo "✔   $f — OK"
                    done

                    echo ""
                    echo "── Checking for Chart.js dependency ──"
                    if grep -q "chart.js" teacher.html; then
                        echo "✔   Chart.js CDN reference found in teacher.html"
                    else
                        echo "⚠   Warning: Chart.js not detected in teacher.html"
                    fi

                    echo "✅  All validation checks passed."
                '''
            }
        }

        // ── 3. DOCKER BUILD ────────────────────────────────────
        stage('Docker Build') {
            steps {
                echo '🐳  Building Docker image...'
                sh """
                    docker build \\
                        --no-cache \\
                        --label "build.number=${env.BUILD_NUMBER}" \\
                        --label "build.commit=${env.GIT_COMMIT}" \\
                        --label "build.branch=${env.GIT_BRANCH}" \\
                        --label "app.name=classsense-ai" \\
                        -t ${IMAGE_NAME}:${IMAGE_TAG} \\
                        -t ${IMAGE_NAME}:latest \\
                        .
                    echo "✅  Image built: ${IMAGE_NAME}:${IMAGE_TAG}"
                """
            }
        }

        // ── 4. SMOKE TEST (local container) ───────────────────
        stage('Smoke Test') {
            steps {
                echo '🧪  Running local smoke test on container...'
                sh """
                    # Start a temporary container
                    docker run -d --name smoke-test-${env.BUILD_NUMBER} -p 8099:80 ${IMAGE_NAME}:${IMAGE_TAG}
                    sleep 4

                    # Test health endpoint
                    STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8099/health)
                    if [ "\$STATUS" != "200" ]; then
                        echo "❌  Smoke test FAILED — /health returned HTTP \$STATUS"
                        docker stop smoke-test-${env.BUILD_NUMBER} && docker rm smoke-test-${env.BUILD_NUMBER}
                        exit 1
                    fi
                    echo "✔   /health → HTTP 200"

                    # Test each page
                    for page in home.html about.html teacher.html; do
                        CODE=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8099/\$page)
                        if [ "\$CODE" != "200" ]; then
                            echo "❌  \$page returned HTTP \$CODE"
                            docker stop smoke-test-${env.BUILD_NUMBER} && docker rm smoke-test-${env.BUILD_NUMBER}
                            exit 1
                        fi
                        echo "✔   /\$page → HTTP \$CODE"
                    done

                    # Cleanup temp container
                    docker stop smoke-test-${env.BUILD_NUMBER}
                    docker rm  smoke-test-${env.BUILD_NUMBER}
                    echo "✅  All smoke tests passed."
                """
            }
        }

        // ── 5. DOCKER PUSH ─────────────────────────────────────
        stage('Push to Registry') {
            steps {
                echo '📤  Pushing image to container registry...'
                withCredentials([usernamePassword(
                    credentialsId: 'docker-registry-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo \$DOCKER_PASS | docker login \$REGISTRY -u \$DOCKER_USER --password-stdin

                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} \$REGISTRY/${IMAGE_NAME}:${IMAGE_TAG}
                        docker tag ${IMAGE_NAME}:latest       \$REGISTRY/${IMAGE_NAME}:latest

                        docker push \$REGISTRY/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push \$REGISTRY/${IMAGE_NAME}:latest

                        echo "✅  Pushed: \$REGISTRY/${IMAGE_NAME}:${IMAGE_TAG}"
                    """
                }
            }
        }

        // ── 6. DEPLOY ──────────────────────────────────────────
        stage('Deploy to Server') {
            steps {
                echo '🚀  Deploying to production server...'
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'deploy-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no \\
                            ${DEPLOY_USER}@\$DEPLOY_HOST \\
                            "
                            echo '── Pulling new image ──'
                            docker pull \$REGISTRY/${IMAGE_NAME}:${IMAGE_TAG}

                            echo '── Stopping old container (if running) ──'
                            docker stop ${CONTAINER} 2>/dev/null || true
                            docker rm   ${CONTAINER} 2>/dev/null || true

                            echo '── Starting new container ──'
                            docker run -d \\
                                --name ${CONTAINER} \\
                                --restart unless-stopped \\
                                -p ${APP_PORT}:80 \\
                                -l 'app=classsense-ai' \\
                                -l 'build=${env.BUILD_NUMBER}' \\
                                \$REGISTRY/${IMAGE_NAME}:${IMAGE_TAG}

                            echo '✅  Container started successfully.'
                            docker ps --filter name=${CONTAINER} --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
                            "
                    """
                }
            }
        }

        // ── 7. HEALTH CHECK ────────────────────────────────────
        stage('Production Health Check') {
            steps {
                echo '❤  Running production health check...'
                sh """
                    sleep 8
                    STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://\$DEPLOY_HOST/health)
                    if [ "\$STATUS" != "200" ]; then
                        echo "❌  Production health check FAILED — HTTP \$STATUS"
                        exit 1
                    fi
                    echo "✅  Production health check PASSED — HTTP 200"
                    echo "🌐  App live at: http://\$DEPLOY_HOST/home.html"
                """
            }
        }
    }

    // ── POST ───────────────────────────────────────────────────
    post {
        success {
            echo """
            ╔══════════════════════════════════════════════╗
            ║  ✅  PIPELINE PASSED                         ║
            ║  Build #${env.BUILD_NUMBER} deployed OK      ║
            ║  Image: ${IMAGE_NAME}:${env.BUILD_NUMBER}    ║
            ╚══════════════════════════════════════════════╝
            """
        }
        failure {
            echo """
            ╔══════════════════════════════════════════════╗
            ║  ❌  PIPELINE FAILED                         ║
            ║  Build #${env.BUILD_NUMBER} — check logs     ║
            ╚══════════════════════════════════════════════╝
            """
        }
        always {
            sh '''
                # Remove dangling smoke test containers (safety cleanup)
                docker rm -f $(docker ps -aq --filter name=smoke-test) 2>/dev/null || true
                docker logout || true
            '''
            cleanWs()
        }
    }
}
