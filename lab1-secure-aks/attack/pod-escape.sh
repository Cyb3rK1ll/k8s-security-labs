#!/bin/bash
LOG_FILE="./evidence/pod-escape.log"
POD_NAME="attacker-$(date +%s)"

echo "=== POD ESCAPE ATTACK - $(date) ===" > $LOG_FILE
echo "POD: $POD_NAME" >> $LOG_FILE

# Borra pod anterior
kubectl delete pod $POD_NAME --ignore-not-found --grace-period=0 --force >> $LOG_FILE 2>&1

# Crea pod persistente
kubectl run $POD_NAME --image=alpine --restart=Never -- /bin/sh -c "sleep 3600" >> $LOG_FILE 2>&1

# Espera
kubectl wait --for=condition=Ready pod/$POD_NAME --timeout=60s >> $LOG_FILE 2>&1

# Ejecuta ataque dentro del pod
kubectl exec $POD_NAME -- /bin/sh -c "
  apk add curl --no-cache
  echo '=== INTENTO METADATA AZURE ==='
  curl -s http://168.63.129.16/metadata/instance && echo 'ACCESO PERMITIDO' || echo 'BLOQUEADO (metadata)'
  echo '=== INTENTO HOSTNETWORK ==='
  cat /etc/hosts | grep -v localhost && echo 'ACCESO PERMITIDO' || echo 'BLOQUEADO (hostNetwork)'
" >> $LOG_FILE 2>&1

# Limpia
kubectl delete pod $POD_NAME --grace-period=0 --force >> $LOG_FILE 2>&1

echo "LOG GUARDADO EN $LOG_FILE"