pipeline {
    agent any

    stages {
// Stage de phase de dévellopement
        stage('BUILD') { 
            steps {
                echo ' Phase de Dev'
                echo "Le numéro de version de ce Job est ${BUILD_ID}"
                echo "L'URL de cette version est ${BUILD_URL}"
//                sh '''
//                cd myapp
//                pip install -r requirements.txt
//                cd
//                sudo docker build -t mybestapp:${BUILD_NUMBER} 
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
//                cd
//                sudo docker run -it mybestapp:${BUILD_NUMBER}
//                curl localhost:5000
//                '''
            }
        }
// Stage de phase de Versionning       
                stage('PACKAGE') {
            steps {
                echo 'Partie Push'
//                sh '''
//              sudo docker push AlexandreCARRON/Odoo-v17_Automatic-deployement-services:${BUILD_NUMBER}
//                '''
                
            }
        }
// Stage de phase de mise en production        
                stage('DEPLOY') {
            steps {
                echo 'Mise en Production'
//              sh '''
//              echo "DevOps to do some 1337 deploy logic here"
//                
            }
        }
    }
}
