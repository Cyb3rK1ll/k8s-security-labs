#!/usr/bin/env bash
set -euo pipefail
mkdir -p evidence/attack-errors

echo "Intentando crear 4 recursos maliciosos (serán rechazados si Gatekeeper está en deny)..."

for f in privileged hostnetwork cap runasnonroot; do
  echo "=== Intento: $f ==="
  case "$f" in
    privileged) file="./attack/privileged-pod.yaml" ;;
    hostnetwork) file="./attack/hostnetwork-pod.yaml" ;;
    cap) file="./attack/capabilities-pod.yaml" ;;
    runasnonroot) file="./attack/runasnonroot-false.yaml" ;;
  esac

  # Aplicar y capturar STDERR en evidencia
  kubectl apply -f "$file" 2> "evidence/attack-errors/${f}.stderr" || true

  # Opcional: mostrar un breve resumen
  echo "Salida (últimas 5 líneas) de ${f}:"
  tail -n 5 "evidence/attack-errors/${f}.stderr" || true
  echo "-------------------------"
done

echo "Hecho. Revisa evidence/attack-errors/ para ver los mensajes de denied."