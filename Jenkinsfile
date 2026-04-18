pipeline {
    agent any

    stages {

        stage('Clone') {
            steps {
                git 'https://github.com/sansgupta3010/PBA-2-TY.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t pba-site .'
            }
        }

        stage('Run Container') {
            steps {
                sh '''
                docker rm -f pba-container || true
                docker run -d -p 8081:80 --name pba-container pba-site
                '''
            }
        }

        stage('Deploy') {
            steps {
                echo 'Website running at http://localhost:8081'
            }
        }
    }
}
