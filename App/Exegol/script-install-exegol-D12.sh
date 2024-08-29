
#******************************** Exegol ****************************************************************************************************

#!/bin/bash

# ********************************************************************* Charger les variables d'environnement à partir du fichier .env *************************************
if [ -f .env ]; then
  export $(cat .env | sed 's/#.*//g' | xargs)
else
  echo "##################### Fichier .env introuvable !"
  exit 1
fi

# Vérifier si NEW_PASSWORD et NEW_USER sont définis
if [ -z "$NEW_PASSWORD" ]; then
  echo "#################### NEW_PASSWORD n'est pas défini dans le fichier .env !"
  exit 1
fi

if [ -z "$NEW_USER" ]; then
  echo "################### NEW_USER n'est pas défini dans le fichier .env !"
  exit 1
fi


# ********************************************************************* Installation d'Exegol *************************************

# install pipx if not already installed, from system package:
echo "################### installation de pipx !"
sudo apt update && sudo apt install pipx -y

# You can now install Exegol package from PyPI
echo "################### installation de exegol via pipx !"
pipx install exegol

# Adding exegol to the PATH
pipx ensurepath

#  ATTENTION IL Y A UN REDEMARRAGE OU RELOG A FAIRE POUR QUE LE NOUVEAU PATH SOIT PRIS EN COMPTE
echo "################### ATTENTION IL Y A UN REDEMARRAGE OU RELOG A FAIRE POUR QUE LE NOUVEAU PATH SOIT PRIS EN COMPTE"

# Run Exegol with appropriate privileges
echo "################### lancement de exegol avec les bons privilèges !"
echo "alias exegol='sudo -E $(which exegol)'" >> ~/.bash_aliases
source ~/.bashrc

# Installation of the first Exegol image
exegol install
