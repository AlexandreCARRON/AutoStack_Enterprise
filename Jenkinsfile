pipeline {
    agent any

    stages {
        stage('BUILD') { #Correspond à la phase de dev
            steps {
                echo ' Phase de Dev'
            }
        }
        
                stage('TEST') {
            steps {
                echo 'Partie Test'
            }
        }
        
                stage('DEPLOY') {
            steps {
                echo 'Mise en Production'
            }
        }
    }
}
