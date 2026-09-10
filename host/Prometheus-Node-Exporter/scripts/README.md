---
id: autostack.host.node-exporter.scripts
kind: guide
status: active
last_reviewed: 2026-09-10
sensitivity: public
sources: ["host/Prometheus-Node-Exporter/service_node-config.txt", "host/Prometheus-Node-Exporter/scripts/command-node-exporter.sh"]
---

# Scripts Prometheus Node Exporter

[`command-node-exporter.sh`](command-node-exporter.sh) installe Node Exporter et le service systemd fourni dans le dossier parent. Il résout ce fichier indépendamment du dossier depuis lequel il est lancé.
