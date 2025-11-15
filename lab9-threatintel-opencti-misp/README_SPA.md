## Laboratorio OpenCTI + MISP (Español)

### Resumen ejecutivo
Este repositorio contiene un laboratorio integral de inteligencia de amenazas donde demuestro mi capacidad para diseñar, asegurar y automatizar ecosistemas CTI de nivel empresarial. **No está pensado para producción tal cual**; la meta es evaluar la integración MISP + OpenCTI y mostrar lo rápido que se despliega (Terraform en EC2, Docker Compose, HAProxy automatizado). Integro MISP para la orquestación de eventos/IOC con OpenCTI para el grafo STIX 2.1, la correlación avanzada y la compartición controlada. Todo corre en Docker Compose sobre Ubuntu 22.04 con HAProxy como proxy TLS y MinIO como almacenamiento tipo S3. Cada servicio, credencial y certificado se maneja como código, lo que permite redeploys reproducibles para clientes y evaluaciones técnicas.

### ¿Por qué operar MISP y OpenCTI juntos?

- **Cosecha + Contexto:** MISP es ideal para ingestión de feeds, taxonomías y atributos; OpenCTI aporta análisis relacional, scoring y casos.
- **Automatización completa:** El conector MISP (v6.8.6) sincroniza eventos etiquetados (TLP:CLEAR, etc.) hacia OpenCTI respetando ventanas temporales e IDs. Los workers y conectores adicionales (AlienVault, MITRE, RansomwareLive) enriquecen el grafo inmediatamente.
- **Gobernanza y escalado:** MISP mantiene CRUD rápido sobre eventos. OpenCTI ofrece API GraphQL, RBAC y modos multi-tenant. Este laboratorio muestra cómo compartimentar funciones (curación vs. análisis) sin sacrificar rendimiento.

### Arquitectura (resumen)

1. **HAProxy** en la EC2 pública aplica TLS 1.2+, ciphers endurecidos, HSTS y balanceo por subdominio.
2. **Docker Compose (proyecto `ti`)** despliega:
   - Redis, Elasticsearch, RabbitMQ, MinIO.
   - OpenCTI platform + workers + 10+ conectores.
   - MISP personalizado con script bootstrap que inicializa MariaDB, crea el usuario admin, aplica `MISP.baseurl` y fuerza las políticas de contraseña.
3. **Persistencia** mediante volúmenes Docker (`misp-db`, `esdata`, etc.) y MinIO para adjuntos.

### Pasos de despliegue

1. **Requisitos:** Cuenta AWS (el flujo Terraform despliega todo allí). Si lo corres manualmente fuera de AWS, usa Ubuntu 22.04 con Docker + Compose, 16 GB RAM y DNS opcional.
2. **Editar `.env`:** define los `*_TOKEN`, `MISP_admin_*`, `CONNECTOR_*_ID`, credenciales de MinIO/RabbitMQ.
3. **Provisionar automáticamente con Terraform (opcional)**
   Terraform puede crear la instancia EC2, copiar `misp-image/`, `docker-compose.yml`, `.env`, ejecutar el script de HAProxy, construir la imagen y levantar la pila:
   ```bash
   cd terraform
   terraform init
   terraform apply \
     -var "key_pair_name=<aws-keypair>" \
     -var "ssh_private_key_path=$HOME/.ssh/<aws-keypair>.pem" \
     -var "haproxy_cert_cn=*.dominio"
   ```
   Al finalizar, el stack ya estará corriendo en `/opt/misp`. Continúa con el “Checklist inicial en MISP”.

4. **Instalar/Configurar HAProxy manualmente (si no usas Terraform)**
   Ejecuta el script de automatización que copia `scripts/haproxy.cfg`, genera el certificado y valida el servicio:
   ```bash
   sudo CERT_CN="*.dominio" CONFIG_SRC="scripts/haproxy.cfg" scripts/setup-haproxy.sh
   ```
5. **Construir y levantar:**
   ```bash
   docker compose build misp
   COMPOSE_PROJECT_NAME=ti docker compose up -d
   ```
6. **Inicializar datos:**
   - Crear organización local y primer evento en MISP.
   - Etiquetar con `TLP:CLEAR`, publicar, añadir atributos/galaxias.
   - Reiniciar el conector `docker restart ti-connector-misp-1`.
   - En OpenCTI validar la ingesta (panel `Data → Ingestión → MISP`).

### Diferenciadores técnicos

- Script bootstrap que integra Bash + PHP (Cake) para mantener contraseñas y baseurl consistentes incluso tras restauraciones.
- Variables en camelCase compatibles con Portainer y Compose estándar.
- Conectores configurados con ISO8601 durations (`PT1H`, `PT30M`, `P2D`), TLS custom CA bundles y puntuaciones ajustadas (AlienVault, Shodan, etc.).
- HAProxy automatizado, con certificados self-signed generados sobre la marcha y pipeline de validación (`haproxy -c`) antes de reiniciar.

### Checklist inicial en MISP

1. **Acceso y endurecimiento**
   - Entra a `https://misp.claumagagnotti.com` con `misp-admin@claumagagnotti.com / changeMeMispAdmin!`.
   - Cambia la contraseña desde `Administration → List Users`.
   - Revisa `Administration → Server Settings & Maintenance → Security` y confirma que `MISP.baseurl` coincide con tu dominio.
   - Verifica que el tag `TLP:CLEAR` exista (`MISP → Global tags`). Si no, créalo (Name `TLP:CLEAR`, Colour `#008000`, Hide Tag `false`).

2. **Crear tu organización**
   - `Administration → List Organisations → Add Organisation`.
   - Nombre ejemplo: `Claumagagnotti CTI`, dominio `claumagagnotti.com`, marca “Local organisation”.
   - Asigna tu usuario a esa organización.

3. **Poblar datos rápidamente**
   - **Evento manual:** `Events → Add Event`, Distribution “This Community only”, Threat Level “Low”, Analysis “Initial”, Tag `TLP:CLEAR`. Añade atributos (dominios/IPs/etc.) y publica.
   - **Plantilla:** `Events → Add Event → Template` (ej. “Ransomware”), completa el asistente y agrega `TLP:CLEAR` antes de publicar.
   - **Feed:** `Sync Actions → List Feeds`, activa uno (CIRCL OSINT), setea `Target Tag = TLP:CLEAR`, ejecuta “Fetch and store” y “Push”.

4. **Garantizar el tag**
   - Dentro del evento usa el botón “Tags” para agregar `TLP:CLEAR`.
   - Para feeds, configura `Target Tag`/`Tag Event` para que se aplique automáticamente.

5. **Confirmar publicación**
   - `Events → List Events`: el candado debe estar abierto y la columna de tags debe mostrar `TLP:CLEAR`.

6. **Ingesta en OpenCTI**
   - El conector corre cada `CONNECTOR_MISP_DURATION_PERIOD` (default `PT1H`). Puedes forzarlo con `docker restart ti-connector-misp-1` o mirando `docker logs -f ti-connector-misp-1`.
   - En OpenCTI, `Data → Ingestion → Monitoring → MISP`: verifica `Last run` y `Processed events`.
   - Los objetos importados aparecen en `Data → Entities → Reports` y `Threats → Indicators` (usa filtros `Created by = MISP`).

7. **Ideas adicionales**
   - Importa STIX/CSV: `Event Actions → Import from STIX` o `Upload sample`.
   - Sincroniza otra instancia MISP desde `Sync Actions → List Instances`.
   - Automatiza con PyMISP (`/events/add`, siempre etiquetando `TLP:CLEAR`).
   - Ajusta `MISP_IMPORT_FROM_DATE` en `.env` si quieres limitar la ventana histórica.

---

### Recorrido visual

| Captura | Descripción |
| --- | --- |
| ![Terraform provisioning](evidence/image.png) | Salida de Terraform + instalación de Docker completando el aprovisionamiento automatizado. |
| ![Portainer stack](evidence/image%20copy.png) | Vista de Portainer mostrando los servicios levantados y su estado. |
| ![OpenCTI ingestion dashboard](evidence/image%20copy%202.png) | Panel “Data → Ingestion → Monitoring” con los conectores activos. |
| ![MISP Add Event form](evidence/image%20copy%203.png) | Formulario “Add Event” de MISP utilizado en el checklist inicial. |
| ![OpenCTI connector detail](evidence/image%20copy%204.png) | Tarjeta de un conector en OpenCTI con métricas de run/health. |
| ![MISP feeds](evidence/image%20copy%205.png) | Configuración de feeds (CIRCL OSINT) etiquetando automáticamente con `TLP:CLEAR`. |
| ![HAProxy bootstrap output](evidence/image%20copy%206.png) | Script `setup-haproxy.sh` generando el certificado y reiniciando el servicio. |
| ![Docker build logs](evidence/image%20copy%207.png) | Resultado de `docker compose build misp` mostrando el build del image local. |
| ![Connector logs](evidence/image%20copy%208.png) | Extracto de `docker logs ti-connector-misp-1` confirmando ingestas. |
| ![OpenCTI entities](evidence/image%20copy%209.png) | Vista de entidades/indicadores en OpenCTI filtradas por origen MISP. |
| ![MISP event list](evidence/image%20copy%2010.png) | “Events → List Events” mostrando eventos publicados con `TLP:CLEAR`. |


Con esta guía muestro a empleadores y clientes que puedo diseñar, automatizar y operar plataformas CTI complejas con seguridad, reproducibilidad y excelencia técnica.
