---
id: autostack.host.windows-server-2022.scripts
kind: guide
status: active
last_reviewed: 2026-09-10
sensitivity: public
sources: ["host/Win-Serv-2022/scripts/script-activate-RDP.ps1", "host/Win-Serv-2022/scripts/script-conf-TLS1.2.ps1", "host/Win-Serv-2022/scripts/script-modify-NTP-server.ps1"]
---

# Scripts Windows Server 2022

- [`script-activate-RDP.ps1`](script-activate-RDP.ps1) active et configure l'accès RDP ;
- [`script-conf-TLS1.2.ps1`](script-conf-TLS1.2.ps1) configure TLS 1.2 dans SCHANNEL et .NET ;
- [`script-modify-NTP-server.ps1`](script-modify-NTP-server.ps1) configure le serveur NTP et le fuseau horaire.

Ces scripts modifient la configuration système et doivent être exécutés depuis une session PowerShell administrateur après revue.
