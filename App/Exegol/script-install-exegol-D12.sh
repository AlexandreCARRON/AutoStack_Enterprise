#******************************** SCRIPT Exegol ****************************************************************************************************

#!/bin/bash

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
read -p "=> REBOOT - Etes-vous ok pour redémarrer le serveur maintenant de manière à ce que le nouveau PATH soit pris en compte ? (Y/n) /n Il vous suffira de relancer le script pour continuer l'installation !" response
response=${response,,} # Convertir en minuscule

if [[ "$response" == "y" || -z "$response" ]]; then
    echo "###### Redémarrage du système..."
    sudo reboot now
else
    echo "#################### Redémarrage annulé. Vous pouvez redémarrer manuellement plus tard. ################"
    echo "#################### La configuration vas continuer mais des erreurs impromptues pouraient apparaitre... ################"
fi

# Run Exegol with appropriate privileges
echo "################### lancement de exegol avec les bons privilèges !"
echo "alias exegol='sudo -E $(which exegol)'" >> ~/.bash_aliases
source ~/.bashrc

# Installation of the first Exegol image
exegol install

# ********************************************************************* Installation du bash-completion permettant d'avoir des suggestions de commandes *************************************

# If the command register-python-argcomplete is not found on your host, you have to install it
sudo apt install python3-argcomplete -y

# To setup the auto-completion system-wide you first need to install bash-completion on your system (if not already installed)
sudo apt update && sudo apt install bash-completion -y

# To generate and install the exegol completion configuration you can execute the following command with register-python-argcomplete
register-python-argcomplete --no-defaults exegol | sudo tee /etc/bash_completion.d/exegol > /dev/null
