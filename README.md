Projet en cours, Readme à rédiger

<h1>Disclaimer</h1>

Bienvenue sur ce méga repo de ouf qui tue sa maman !! 

Mouai... C'est en cours de dev, et je n'ai pas beaucoup de bande passante à consacrer à ce projet pour le moment, donc ça avance au fur et à mesure, et il y a encore pas mal de choses à améliorer ! 

Pleins de mauvaises pratiques tu trouvera ici jeune padawan (genre des :ro inexistants... mais sais tu seulement de quoi je parle ?) !
Pour les maîtres Jedi, j'ai soif d'apprentissage, donc n'hésite pas à commenter les fichiers pour qu'on puisse améliorer ça ensemble ! Dans la bienveillance tu agiras, en toute humilité je réagirai !!

Voici à date les améliorations à venir que j'envisage à cours terme : 
    - Améliorer la gestion des variables
    - Script d'automatisation config machine hote
    - Meilleur gestion des entrypoint
    - Suppression des dossiers et fichiers (fake.md nottament) inutiles
    - Pondre une fucking doc digne de ce nom

Je suis preneur de toute aide autour de ce projet. En gros l'idée est de faire une stack facile à mettre en place pour qu'on puisse aider les startups de notre Startup Nation (Youhou !), ou autres projets à impact, à avoir des outils efficients et peux couteux pour qu'ils puissent tester leurs idées et scaller rapidement (je me fais presque peur avec mon vocabulaire !). Bref ! En vrai je m'amuse à faire un projet qui, je l'espère, servira à d'autres pour gagner du temps sur leurs déploiements sans trop dépenser d'argent !

Voila fin du disclamer : Pour ton infra, je m'occupe de rien, tu s'occupe de tout, et je ne saurai être tenu responsable d'une mauvaise utilisation ou d'un bug lié à ce repo !

Bisous Merci Bisous !

<h1>Pré-paramétrage</h1>

<h2>pré-paramétrage à la mano (très light)</h2>

Installer docker engine : <link>https://docs.docker.com/engine/install/</link>

Installer git : <code>sudo apt install git</code>

<h2>pré-paramétrage automatisé via script</h2>
Se logguer sur votre serveur fraichement installé.

Créer les fichiers suivants sur le serveur host et copier coller le contenu des fichiers depuis le repo Git. 

Copiez le contenu trouvé dans ./script-conf-server-D12.sh dans ce fichier : <code>sudo nano script.sh</code>

Copiez les lignes relatives à CONFIG SERVEUR du fichier ./.env dans ce fichier : <code>sudo nano .env</code>

Rendez exécutable le fichier script.sh : <code>sudo chmod +x script.sh</code>

Executez ensuite le script : <code>./script.sh</code>

<h3>VOILA ! /!\ NE PAS OUBLIER DE SUPPRIMER LES 2 FICHIERS CREES POUR UN MINIMUM DE SECURITE /!\</h3>



<h1>Déploiement de l'infra</h1>

Importer le repo : <code>sudo git clone https://github.com/AlexandreCARRON/Odoo-v17_Automatic-deployement-services.git</code>

Se rendre dans le dossier copié : <code>cellelatulatrouvetoutseulnonmais!</codde>

Pour le premier dépoiement histoire de vérifier que tout se passe bien : 

<code> sudo docker-compose up </code>

En non verbeux pour pouvoir utiliser le shell ensuite (le -d s'ignifie daemon => s'execute en arrière plan)

<code> sudo docker-compose up -d </code>

<h1>Sécurité</h1>

<h2>Gestion des mots de passe</h2> 
/!\ Attention à bien changer les mots de passe dans le fichier docker-compose.yml ET dans le odoo.conf ET dans le .env (a terme plus de mdp dans docker-compose.yml) !!! /!\

<h2>Gestion des ports</h2>
Les ports exposés sont déjà des ports pas communs donc c'est relativement bien. 
Mais ce repo est public, donc des petits malins peuvent peut être connaitre vos ports d'exposition si vous ne les changez pas. 

Pensez à changer tous les ports en 220XX avant de lancer votre infra ;) Et si je l'ai écrit trop tard, faite un <code>docker compose down</code>, éditez le fichier docker-compose.yml, puis relancez. Sorry pour les manips, mais console toi en te disans que c'est le métier qui rentre jeune padawan !

<h1>Commandes utiles</h1>

En principe, avant de taper les commandes, vous avez mis votre utilisateur dans les sudoers, donc le sudo en début de commande n'est pas nécessaire...

<h2>liste des containers UP</h2>
<code>sudo docker ps</code>
<h2>liste des volumes</h2>
<code>sudo docker ls</code>
<h2>Copier fichier/dossier depuis container vers host</h2>
<code>sudo docker cp <container_id>:/path/to/file /host/path/to/destination</code>
<h2>Afficher contenu d'un fichier du container depuis machine hote</h2>
<code>sudo docker exec <container_id> cat /path/to/file</code>

<h1>Licence</h1>

Ce contenu est en licence GNU GPLv3, il peut être réutilisé comme bon vous semble, c'est cadeau ! Détails dans le fichier de licence.

Petite pub discrète de fin pour que je puisse bouffer :  https://alexandrecarron.fr ! Enjoy !
