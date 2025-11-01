#!/bin/bash
LOG_FILE="./evidence/pod-escape.log"
POD_NAME="attacker-$(date +%s)"

echo "=== POD ESCAPE ATTACK - $(date) ===" > $LOG_FILE
echo "POD: $POD_NAME" >> $LOG_FILE

kubectl delete pod $POD_NAME --ignore-not-found --grace-period=0 --force >> $LOG_FILE 2>&1

kubectl run $POD_NAME --image=alpine --restart=Never -- /bin/sh -c "
  apk add curl --no-cache > /dev/null 2>&1
  echo '=== INTENTO IMDS AWS ==='
  if curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/ | grep -q .; then
    echo 'ACCESO PERMITIDO (IMDS)'
  else
    echo 'BLOQUEADO (IMDS)'
  fi
  echo '=== INTENTO HOSTNETWORK ==='
  if cat /etc/hosts | grep -v localhost | grep -q -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
    HOST_IP=\$(cat /etc/hosts | grep -v localhost | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print \$1}')
    if [[ \$HOST_IP == 10.0.* ]]; then
      echo 'BLOQUEADO (hostNetwork) - solo IP del pod'
    else
      echo 'ACCESO PERMITIDO (hostNetwork)'
    fi
  else
    echo 'BLOQUEADO (hostNetwork)'
  fi
" >> $LOG_FILE 2>&1

kubectl wait --for=condition=Ready pod/$POD_NAME --timeout=60s >> $LOG_FILE 2>&1
kubectl logs $POD_NAME --tail=50 >> $LOG_FILE 2>&1
kubectl delete pod $POD_NAME --grace-period=0 --force >> $LOG_FILE 2>&1

echo "LOG GUARDADO EN $LOG_FILE"