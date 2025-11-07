#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/defectdojo_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "============================================================"
echo " 🐳 Instalador automático de DefectDojo (Amazon Linux 2023)"
echo "============================================================"
echo "Inicio: $(date)"
echo

### --- Paso 1: Actualización base ---
echo "=== [1/6] Actualizando sistema base ==="
sudo dnf update -y
sudo dnf install -y git curl --allowerasing

### --- Paso 2: Instalar Docker y Compose ---
echo
echo "=== [2/6] Instalando Docker y Compose ==="
if ! command -v docker &>/dev/null; then
  sudo dnf install -y docker
  sudo usermod -aG docker ec2-user
fi
sudo systemctl enable --now docker

# Verificar Docker
if ! sudo docker info &>/dev/null; then
  echo "❌ Docker no se pudo iniciar correctamente. Abortando."
  exit 1
fi
echo "✅ Docker activo y corriendo."

# Instalar plugin Compose (si no existe)
if ! sudo docker compose version &>/dev/null; then
  echo "Instalando Docker Compose plugin..."
  sudo mkdir -p /usr/libexec/docker/cli-plugins
  sudo curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/libexec/docker/cli-plugins/docker-compose
  sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
fi
sudo docker compose version || { echo "❌ Docker Compose no disponible"; exit 1; }

### --- Paso 3: Clonar repositorio ---
echo
echo "=== [3/6] Clonando repositorio DefectDojo ==="
cd /home/ec2-user
if [ -d "django-DefectDojo" ]; then
  echo "Directorio existente, eliminando..."
  sudo rm -rf django-DefectDojo
fi
sudo -u ec2-user git clone https://github.com/DefectDojo/django-DefectDojo.git
cd django-DefectDojo

### --- Paso 4: Crear archivo de entorno ---
echo
echo "=== [4/6] Creando archivo de entorno (.env) ==="
sudo -u ec2-user tee /home/ec2-user/django-DefectDojo/.env >/dev/null <<'EOF'
DD_ADMIN_USER=admin
DD_ADMIN_MAIL=admin@example.com
DD_CELERY_WORKER_AUTOSCALE=2,1
DD_ALLOWED_HOSTS=*
DD_DEBUG=False
EOF
echo "✅ Archivo .env creado."

### --- Paso 5: Desplegar contenedores ---
echo
echo "=== [5/6] Construyendo e iniciando contenedores ==="
sudo docker compose pull
sudo docker compose up -d

# Esperar hasta que postgres esté listo antes de continuar
echo "⏳ Esperando que PostgreSQL inicialice..."
timeout 180 bash -c 'until sudo docker compose ps | grep -q "postgres.*Up"; do sleep 5; done'
echo "✅ Contenedores inicializados."

### --- Paso 6: Extraer credenciales ---
echo
echo "=== [6/6] Capturando credenciales del usuario admin ==="
sleep 240 # darle tiempo a initializer a terminar
sudo touch /home/ec2-user/defectdojo_admin_credentials.log
sudo chmod 600 /home/ec2-user/defectdojo_admin_credentials.log
sudo chown ec2-user:ec2-user /home/ec2-user/defectdojo_admin_credentials.log
sudo docker compose logs initializer > /home/ec2-user/defectdojo_initializer.log 2>&1 || true
admin_pw=$(
  grep "Admin password:" /home/ec2-user/defectdojo_initializer.log | tail -1 | awk -F':' '{print $2}' | xargs
)

if [ -n "$admin_pw" ]; then
  echo "Admin password: $admin_pw" | sudo tee /home/ec2-user/defectdojo_admin_credentials.log >/dev/null
  sudo chown ec2-user:ec2-user /home/ec2-user/defectdojo_admin_credentials.log
  chmod 600 /home/ec2-user/defectdojo_admin_credentials.log
  echo "✅ Contraseña extraída correctamente."
else
  echo "⚠️  No se detectó contraseña en logs del initializer."
  echo "   Verificá manualmente: /home/ec2-user/defectdojo_initializer.log"
fi

### --- Resultado final ---
echo
echo "============================================================"
echo " 🎉 Instalación completa de DefectDojo"
echo "------------------------------------------------------------"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "0.0.0.0")
echo "URL: http://$PUBLIC_IP:8080"
echo "Usuario: admin"
iif [ -n "$admin_pw" ]; then
  echo "Admin password: $admin_pw" | sudo tee /home/ec2-user/defectdojo_admin_credentials.log >/dev/null
  chmod 600 /home/ec2-user/defectdojo_admin_credentials.log
  echo "✅ Contraseña extraída correctamente."
else
  echo "⚠️  No se detectó contraseña en logs del initializer."
  echo "   Verificá manualmente: /home/ec2-user/defectdojo_initializer.log"
fi

echo "============================================================"