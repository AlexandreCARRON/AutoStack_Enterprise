# Activer le service RDP (Remote Desktop)
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0

# Autoriser les connexions RDP via le pare-feu Windows
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Optionnel : Configurer le niveau de sécurité du RDP (NLA - Network Level Authentication)
# Si tu veux forcer l'authentification au niveau réseau (NLA), utilise la ligne suivante
# Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1

# Demander le nom d'utilisateur ou de groupe à autoriser
$Username = Read-Host "Entrez le nom d'utilisateur ou du groupe à ajouter au groupe 'Remote Desktop Users'"

# Vérifier si l'utilisateur ou le groupe existe avant de l'ajouter
$UserExists = [ADSI]"WinNT://$env:COMPUTERNAME/$Username"
if ($UserExists -ne $null) {
    # Ajouter l'utilisateur ou le groupe au groupe 'Remote Desktop Users'
    ([ADSI]"WinNT://$env:COMPUTERNAME/Remote Desktop Users,group").Add("WinNT://$env:COMPUTERNAME/$Username,user")
    Write-Host "L'utilisateur ou le groupe '$Username' a été ajouté au groupe 'Remote Desktop Users'."
} else {
    Write-Host "L'utilisateur ou le groupe '$Username' n'existe pas sur ce système. Veuillez vérifier et réessayer."
}

Write-Host "Le RDP a été activé avec succès. N'oubliez pas de vérifier les configurations réseau et de redémarrer le service si nécessaire."
