pipeline {
    agent any

    stages {
// Stage de phase de dévellopement
        stage('BUILD') { 
            steps {
                echo ' Phase de Dev'
            }
        }
// Stage de phase de tests        
                stage('TEST') {
            steps {
                echo 'Partie Test'
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
