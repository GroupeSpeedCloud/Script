#!/bin/bash

# Variables à personnaliser
domain="auth.mondomaine.com"
email="admin@mondomaine.com"
authentik_version="2024.2.2"
install_dir="/opt/authentik"
postgres_password="$(openssl rand -base64 32)"
authentik_secret_key="$(openssl rand -base64 50)"

# Prérequis
sudo apt update
sudo apt install -y docker.io docker-compose

# Création du dossier
sudo mkdir -p "$install_dir"
cd "$install_dir"

# Création du fichier docker-compose.yml
cat <<EOF | sudo tee docker-compose.yml
version: "3.4"

services:
  traefik:
    image: traefik:v2.10
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=$email"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    restart: unless-stopped

  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: $postgres_password
      POSTGRES_USER: authentik
      POSTGRES_DB: authentik
    volumes:
      - ./postgres:/var/lib/postgresql/data
    restart: unless-stopped

  authentik-server:
    image: ghcr.io/goauthentik/server:$authentik_version
    environment:
      AUTHENTIK_SECRET_KEY: "$authentik_secret_key"
      AUTHENTIK_POSTGRESQL__HOST: postgres
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__NAME: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD: $postgres_password
      AUTHENTIK_EMAIL__HOST: "localhost"
      AUTHENTIK_EMAIL__PORT: 25
      AUTHENTIK_EMAIL__FROM: "$email"
      AUTHENTIK_ERROR_REPORTING__ENABLED: "false"
    depends_on:
      - postgres
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.authentik.rule=Host(\`$domain\`)"
      - "traefik.http.routers.authentik.entrypoints=websecure"
      - "traefik.http.routers.authentik.tls.certresolver=letsencrypt"
    restart: unless-stopped

  authentik-worker:
    image: ghcr.io/goauthentik/server:$authentik_version
    command: worker
    environment:
      AUTHENTIK_SECRET_KEY: "$authentik_secret_key"
      AUTHENTIK_POSTGRESQL__HOST: postgres
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__NAME: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD: $postgres_password
    depends_on:
      - postgres
    restart: unless-stopped
EOF

# Création des dossiers nécessaires
sudo mkdir -p ./letsencrypt ./postgres

# Lancement des services
sudo docker-compose up -d

echo "Authentik est en cours d'installation."
echo "Accédez à https://$domain après quelques minutes."
echo "Pour voir les logs : cd $install_dir && sudo docker-compose logs -f"
