---
id: autostack.apisix.demo-3-18-0.bootstrap
kind: guide
status: active
last_reviewed: 2026-09-17
sensitivity: public
sources: ["services/APISIX/scripts/bootstrap.py"]
---

# Bootstrap de la démonstration

[`bootstrap.py`](bootstrap.py) applique de façon idempotente la configuration de la démonstration.

Le script attend APISIX, Keycloak, Logstash et Kibana, puis crée les upstreams, routes, consommateurs et credentials. Il insère le certificat client dans l'upstream mTLS, ajoute une route OIDC `bearer_only`, ajoute une route navigateur de type BFF et prépare la vue de données Kibana `apisix-demo-*`.

Les appels à Kibana sont authentifiés avec le compte administrateur de démonstration. Avant ce bootstrap, [`setup-elastic.py`](setup-elastic.py) crée ce compte et les comptes techniques dédiés à Kibana et Logstash.

Les deux routes OIDC utilisent le document de découverte du realm `autostack`. Le flux machine-à-machine vérifie les signatures avec le JWKS Keycloak. Le flux BFF utilise Authorization Code avec PKCE et une session HTTP-only dont le secret provient du `.env` local.

Il est exécuté par le service Compose `demo-configurator` via [`start-apisix-demo.sh`](start-apisix-demo.sh) et ne doit pas être lancé directement sur l'hôte.
