Projet en cours, Readme à rédiger


<h1>Pré-paramétrage</h1>

Installer docker engine : <link>https://docs.docker.com/engine/install/</link>

Installer git : \n<code>sudo apt install git</code>

Importer le repo : \n<code>sudo git clone https://github.com/AlexandreCARRON/Odoo-v17_Automatic-deployement-services.git</code>


<h1>Déploiement de l'infra</h1>
Commande à executer : 

Pour le premier dépoiement histoire de vérifier que tout se passe bien : 
\n<code> sudo docker-compose up </code>

En non verbeux pour pouvoir utiliser le shell ensuite (le -d s'ignifie daemon => s'execute en arrière plan)
\n<code> sudo docker-compose up -d </code>


Gestion des mots de passe : 
/!\ Attention à bien changer les mots de passe dans le fichier docker-compose.yml ET dans le odoo.conf ET dans le .env (a terme plus de mdp dans docker-compose.yml) !!! /!\

