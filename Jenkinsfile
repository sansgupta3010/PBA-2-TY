pipeline {
    agent any

    stages {

        stage('Build Docker Image') {
            steps {
                sh '/usr/local/bin/docker build -t pba-site .'
            }
        }

        stage('Run Container') {
            steps {
                sh '''
                /usr/local/bin/docker rm -f pba-container || true
                /usr/local/bin/docker run -d -p 8081:80 --name pba-container pba-site
                '''
            }
        }

        stage('Deploy to XAMPP') {
            steps {
                sh 'cp /var/jenkins_home/workspace/PBA-2-TY/*.html /Applications/XAMPP/xamppfiles/htdocs/'
            }
        }
    }
}
