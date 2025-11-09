#!/bin/bash
set -euo pipefail

PROJECT_DIR="/home/ec2-user/django-DefectDojo"
POSTGRES_CONTAINER="django-defectdojo-postgres-1"
MEDIA_VOLUME="django-defectdojo_django-media"
BACKUP_DIR_DEFAULT="/home/ec2-user/backups"

usage() {
  echo "Uso: $0 <bucket> <db_object_key> <media_object_key> [backup_dir]" >&2
  exit 1
}

if [ "$#" -lt 3 ]; then
  usage
fi

BUCKET="$1"
DB_OBJECT="$2"
MEDIA_OBJECT="$3"
BACKUP_DIR="${4:-$BACKUP_DIR_DEFAULT}"

if [ -z "$BUCKET" ] || [ -z "$DB_OBJECT" ] || [ -z "$MEDIA_OBJECT" ]; then
  usage
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "❌ No se encontró el directorio del proyecto en $PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"

DB_FILENAME="$(basename "$DB_OBJECT")"
MEDIA_FILENAME="$(basename "$MEDIA_OBJECT")"

echo "⬇️  Descargando backups desde s3://$BUCKET..."
aws s3 cp "s3://$BUCKET/$DB_OBJECT" "$DB_FILENAME"
aws s3 cp "s3://$BUCKET/$MEDIA_OBJECT" "$MEDIA_FILENAME"

cd "$PROJECT_DIR"

echo "🛑 Deteniendo contenedores de DefectDojo..."
sudo docker compose down || true

echo "🚀 Arrancando Postgres para restaurar la base..."
sudo docker compose up -d postgres
echo "⏳ Esperando a que Postgres esté listo..."
timeout 180 bash -c 'until sudo docker compose ps | grep -q "postgres.*Up"; do sleep 5; done'

echo "🧹 Reiniciando base de datos defectdojo..."
sudo docker exec -i "$POSTGRES_CONTAINER" psql -U defectdojo postgres <<'SQL'
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'defectdojo' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS defectdojo;
CREATE DATABASE defectdojo OWNER defectdojo;
SQL

echo "🗄️  Restaurando base de datos desde $DB_FILENAME..."
sudo docker exec -i "$POSTGRES_CONTAINER" psql -U defectdojo postgres < "$BACKUP_DIR/$DB_FILENAME"

echo "🗂️  Restaurando media files desde $MEDIA_FILENAME..."
sudo docker run --rm \
  -v "$MEDIA_VOLUME":/data \
  -v "$BACKUP_DIR":/backup \
  alpine sh -c "set -e; find /data -mindepth 1 -delete; tar xzf /backup/$MEDIA_FILENAME -C /"

echo "🔁 Arrancando nuevamente todo el stack..."
sudo docker compose up -d
echo "⏳ Esperando que uwsgi esté listo..."
timeout 240 bash -c 'until sudo docker compose ps | grep -q "uwsgi.*Up"; do sleep 5; done'

echo "🔐 Generando nueva contraseña para el usuario admin..."
NEW_ADMIN_PW=$(openssl rand -base64 24 | tr -d '\n' | cut -c1-24)

sudo docker compose exec -T uwsgi /bin/bash -c "
  set -e
  export ADMIN_PW='$NEW_ADMIN_PW'
  python manage.py shell <<'PY'
import os
from django.contrib.auth import get_user_model
User = get_user_model()
user = User.objects.get(username='admin')
user.set_password(os.environ['ADMIN_PW'])
user.save()
print('Admin password reset')
PY
"

sudo tee /home/ec2-user/defectdojo_admin_credentials.log >/dev/null <<EOF
Admin password: $NEW_ADMIN_PW
EOF
sudo chown ec2-user:ec2-user /home/ec2-user/defectdojo_admin_credentials.log
sudo chmod 600 /home/ec2-user/defectdojo_admin_credentials.log

echo "✅ Restore completo y contraseña reseteada. Revisá los contenedores con 'docker compose ps'. Nueva password: $NEW_ADMIN_PW"
