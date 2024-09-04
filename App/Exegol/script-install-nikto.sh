#!/bin/bash

# Script pour installer Nikto sur un système Debian/Ubuntu

sudo apt update

sudo apt install git perl

cd /opt

sudo git clone https://github.com/sullo/nikto.git

sudo ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto

echo "si pas d'erreur ci dessus, nikto est maintenant installé et pret à etre utilisé"
