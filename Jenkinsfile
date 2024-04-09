pipeline {
    agent any

    stages {
// Stage de phase de dévellopement
        stage('BUILD') { 
            steps {
                echo ' Phase de Dev'
//                sh '''
//                cd myapp
//                pip install -r requirements.txt
//                '''
            }
        }
// Stage de phase de tests        
                stage('TEST') {
            steps {
                echo 'Partie Test'
//                sh '''
//                cd myapp
//                python3 hello.py
//                python3 hello.py --name=Brad
//                '''
            }
        }
// Stage de phase de Versionning       
                stage('PACKAGE') {
            steps {
                echo 'Partie Realese'
            }
        }
// Stage de phase de mise en production        
                stage('DEPLOY') {
            steps {
                echo 'Mise en Production'
            }
        }
    }
}
