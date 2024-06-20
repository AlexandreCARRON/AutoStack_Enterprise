Projet en cours, Readme à rédiger


<h1>Pré-paramétrage</h1>

Installer docker engine : <link>https://docs.docker.com/engine/install/</link>

Installer git : <code>sudo apt install git</code>

Importer le repo : <code>sudo git clone https://github.com/AlexandreCARRON/Odoo-v17_Automatic-deployement-services.git</code>


<h1>Déploiement de l'infra</h1>
Commande à executer : 

Pour le premier dépoiement histoire de vérifier que tout se passe bien : 
<code> sudo docker-compose up </code>

En non verbeux pour pouvoir utiliser le shell ensuite (le -d s'ignifie daemon => s'execute en arrière plan)
<code> sudo docker-compose up -d </code>


<h1>Gestion des mots de passe</h1> 
/!\ Attention à bien changer les mots de passe dans le fichier docker-compose.yml ET dans le odoo.conf ET dans le .env (a terme plus de mdp dans docker-compose.yml) !!! /!\

<h1>Commandes utiles</h1>
En principe, avant de tapper les commandes, vous avez mis votre utilisateur dans les sudoers, donc le sudo en début de commande n'est pas nécessaire...
<h2>liste des containers UP</h2>
<code>sudo docker ps</code>
<h2>liste des volumes</h2>
<code>sudo docker ls</code>
<h2>Copier fichier/dossier depuis container vers host</h2>
<code>sudo docker cp <container_id>:/path/to/file /host/path/to/destination</code>
<h2>Afficher contenu d'un fichier du container depuis machine hote</h2>
<code>sudo docker exec <container_id> cat /path/to/file</code>

