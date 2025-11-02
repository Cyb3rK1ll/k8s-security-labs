#!/bin/bash

# Config
LOG_FILE="../evidence/lateral-move.log"
ATTACKER_POD="attacker"
VICTIM_POD="victim"
NAMESPACE="default"

# Limpia log
> "$LOG_FILE"

echo "=== LATERAL MOVE ATTACK - $(date) ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Función: eliminar pod si existe
delete_pod_if_exists() {
  local pod_name=$1
  if kubectl get pod "$pod_name" -n "$NAMESPACE" &>/dev/null; then
    echo "[INFO] Eliminando pod existente: $pod_name" >> "$LOG_FILE"
    kubectl delete pod "$pod_name" -n "$NAMESPACE" --grace-period=0 --force &>/dev/null || true
    # Espera a que se elimine
    while kubectl get pod "$pod_name" -n "$NAMESPACE" &>/dev/null; do
      sleep 1
    done
  fi
}

# Elimina pods previos
delete_pod_if_exists "$ATTACKER_POD"
delete_pod_if_exists "$VICTIM_POD"

# Crea pod atacante (con curl)
echo "[+] Creando pod atacante: $ATTACKER_POD" >> "$LOG_FILE"
kubectl run "$ATTACKER_POD" --image=alpine --restart=Never -- sleep 3600 >> "$LOG_FILE" 2>&1

# Espera a que esté listo
echo "[WAIT] Esperando pod atacante..." >> "$LOG_FILE"
kubectl wait --for=condition=Ready pod/"$ATTACKER_POD" -n "$NAMESPACE" --timeout=60s >> "$LOG_FILE" 2>&1

# Crea pod víctima
echo "[+] Creando pod víctima: $VICTIM_POD" >> "$LOG_FILE"
kubectl run "$VICTIM_POD" --image=nginx --restart=Never >> "$LOG_FILE" 2>&1

# Espera a que esté listo
echo "[WAIT] Esperando pod víctima..." >> "$LOG_FILE"
kubectl wait --for=condition=Ready pod/"$VICTIM_POD" -n "$NAMESPACE" --timeout=60s >> "$LOG_FILE" 2>&1

# Instala curl en atacante
echo "[+] Instalando curl en atacante..." >> "$LOG_FILE"
kubectl exec "$ATTACKER_POD" -- apk add --no-cache curl >> "$LOG_FILE" 2>&1

# Intenta conexión
echo "[ATTACK] Intentando curl desde $ATTACKER_POD a $VICTIM_POD:80" >> "$LOG_FILE"
if kubectl exec "$ATTACKER_POD" -- curl -s --connect-timeout 5 "$VICTIM_POD":80; then
  echo "[FAILED] CONEXIÓN EXITOSA (NetworkPolicy NO BLOQUEA)" >> "$LOG_FILE"
else
  echo "[SUCCESS] CONEXIÓN BLOQUEADA (NetworkPolicy FUNCIONA)" >> "$LOG_FILE"
fi

# Spawnea shell
#echo "[+] Spawneando shell en $ATTACKER_POD..." >> "$LOG_FILE"
#kubectl exec "$ATTACKER_POD" -- sh -c "echo 'Shell spawned in container (user=\$(whoami))'" >> "$LOG_FILE" 2>&1
echo "[+] Spawneando shell real en $ATTACKER_POD..." >> "$LOG_FILE"
kubectl exec -i -t "$ATTACKER_POD" -- sh -c "echo Shell spawned && sleep 5" >> "$LOG_FILE" 2>&1

echo "" >> "$LOG_FILE"
echo "=== ATAQUE COMPLETADO - $(date) ===" >> "$LOG_FILE"
echo "LOG GUARDADO EN: $LOG_FILE"