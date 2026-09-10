---
id: autostack.apisix.scripts
kind: guide
status: active
last_reviewed: 2026-09-10
sensitivity: public
sources: ["services/APISIX/README.md", "services/APISIX/DEMO.md"]
---

# Scripts APISIX

Ces scripts agissent uniquement sur APISIX et ses variantes :

- [`install-APISIX.sh`](install-APISIX.sh) installe la variante maintenue ;
- [`configure-docker-insecure-registries.sh`](configure-docker-insecure-registries.sh) encadre l'exception TLS temporaire utilisée par le workflow APISIX ;
- [`generate-apisix-demo-config.py`](generate-apisix-demo-config.py) convertit le classeur de démonstration en objets JSON ;
- [`bootstrap.py`](bootstrap.py) applique ces objets à APISIX et prépare Kibana ;
- [`server.py`](server.py) fournit les API fictives interne et partenaire ;
- [`client.py`](client.py) exécute les appels des scénarios réseau ;
- [`start-apisix-demo.sh`](start-apisix-demo.sh), [`run-apisix-demo-scenarios.sh`](run-apisix-demo-scenarios.sh) et [`stop-apisix-demo.sh`](stop-apisix-demo.sh) pilotent la démonstration ;
- [`install-legacy-poc.sh`](install-legacy-poc.sh) conserve l'ancien installateur à titre documentaire et ne doit pas servir à un nouveau déploiement.

Le manifeste Compose monte `bootstrap.py` et `client.py` depuis ce dossier. Il construit l'image de `server.py` avec [`Dockerfile.demo-api`](Dockerfile.demo-api). Les rôles de ces trois programmes sont détaillés dans [`BOOTSTRAP.md`](BOOTSTRAP.md), [`DEMO_API.md`](DEMO_API.md) et [`DEMO_CLIENT.md`](DEMO_CLIENT.md).

Le dossier APISIX est autonome. Après l'avoir copié, les scripts se lancent depuis sa racine et ses tests restent disponibles :

```bash
./scripts/install-APISIX.sh
python3 -m unittest discover -s tests -v
```
