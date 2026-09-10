---
id: autostack.apisix.3-18-0.inputs
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_v3.18.0/fichiers/AutoStack_Demo_APISIX.xlsx"]
---

# Fichiers d'entrée APISIX

[`AutoStack_Demo_APISIX.xlsx`](AutoStack_Demo_APISIX.xlsx) décrit le partenaire, le backend, l'upstream, la route, la sécurité et les plugins de la démonstration.

Le générateur [`../../scripts/generate-apisix-demo-config.py`](../../scripts/generate-apisix-demo-config.py) lit ce classeur sans le modifier et produit les objets JSON dans le répertoire d'exécution ignoré par Git de la variante de démonstration.

[`fake.md`](fake.md) est un fichier de conservation historique ; il ne constitue pas une configuration active.
