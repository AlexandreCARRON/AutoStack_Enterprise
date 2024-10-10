# Proposer à l'utilisateur d'entrer un serveur de temps ou d'utiliser le serveur Google par défaut
$defaultTimeServer = "time.google.com"
$customTimeServer = Read-Host "Entrez l'adresse ou l'IP de votre serveur de temps (appuyez sur Entrée pour utiliser le serveur Google par défaut : $defaultTimeServer)"

# Utiliser le serveur par défaut si l'utilisateur n'entre rien
if ([string]::IsNullOrEmpty($customTimeServer)) {
    $timeServer = $defaultTimeServer
} else {
    $timeServer = $customTimeServer
}

Write-Host "Le serveur de temps sélectionné est : $timeServer"

# Arrêter le service de temps Windows (w32time) avant de faire des modifications
Stop-Service w32time

# Configurer le serveur de temps (Google ou personnalisé)
w32tm /config /manualpeerlist:$timeServer /syncfromflags:manual /reliable:YES /update

# Redémarrer le service de temps Windows (w32time)
Start-Service w32time

# Réinitialiser la configuration de temps et forcer une synchronisation immédiate avec le serveur
w32tm /resync

# Vérifier la configuration pour s'assurer que le serveur de temps est bien pris en compte
w32tm /query /status

Write-Host "La configuration du serveur de temps est terminée. Le serveur de temps a été synchronisé avec $timeServer."
