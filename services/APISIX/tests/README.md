---
id: autostack.apisix.tests
kind: guide
status: active
last_reviewed: 2026-09-10
sensitivity: public
sources: ["services/APISIX/scripts/README.md", "services/APISIX/tests/test_generate_apisix_demo_config.py"]
---

# Tests APISIX

Ce dossier contient les tests propres au service APISIX :

- [`test_apisix_readmes.py`](test_apisix_readmes.py) contrôle la présence des README du service ;
- [`test_docker_insecure_registries.py`](test_docker_insecure_registries.py) vérifie le helper TLS Docker ;
- [`test_generate_apisix_demo_config.py`](test_generate_apisix_demo_config.py) vérifie les objets générés depuis le classeur.

Depuis la racine du dossier APISIX, y compris après copie hors du dépôt :

```bash
python3 -m unittest discover -s tests -v
```
