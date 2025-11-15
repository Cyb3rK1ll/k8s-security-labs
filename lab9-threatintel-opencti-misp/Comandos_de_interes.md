# Conectarse a la instancia EC2
chmod 600 ssh-key.pem 
ssh -i clau-key.pem ec2-user@34.242.74.206

# Generar certificado autofirmado para el dominio
sudo mkdir -p /etc/ssl/purple
sudo openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout /etc/ssl/purple/private.key \
  -out /etc/ssl/purple/fullchain.pem \
  -days 365 -subj "/CN=*.claumagagnotti.com"

sudo sh -c 'cat /etc/ssl/purple/private.key /etc/ssl/purple/fullchain.pem > /etc/ssl/purple/haproxy.pem'

sudo chmod 600 /etc/ssl/purple/haproxy.pem


# Instalar y configurar haproxy
apt-get install -y haproxy
# aplicar la configuracion del archivo haproxy.cfg
# validar y reiniciar haproxy
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy



# Prep MISP

Accedé a https://misp.claumagagnotti.com como misp-admin@claumagagnotti.com / changeMeMispAdmin!. Cambiá la contraseña desde Administration → List Users si no lo hiciste.
Verificá en Administration → Server Settings & Maintenance → Security que MISP.baseurl sea https://misp.claumagagnotti.com y en MISP → Global tags que exista TLP:CLEAR. Si no está, añadilo (Add Tag → Name=TLP:CLEAR, Colour=#008000, Hide Tag=false).
Crear una organización propia

Administration → List Organisations → Add Organisation.
Nombre: Claumagagnotti CTI, dominio claumagagnotti.com, marcá “Local organisation”.
Guardá y asignate a esa org (en tu usuario → Edit, Organisation = Claumagagnotti CTI).
Popular con datos (tres opciones rápidas):

Evento manual

Events → Add Event.
Completa:
Distribution: “This Community only” (o “All communities” si vas a compartir).
Threat Level: “Low”.
Analysis: “Initial”.
Tags: agrega TLP:CLEAR.
Guardá; luego dentro del evento usa Add Attribute para cargar IOCs (ej. Type=domain, Value=malicioso.com).
Publicalo con “Publish Event”.
Plantilla rápida

Events → Add Event, en la parte inferior “Template”. Elegí una plantilla (por ejemplo “Ransomware”).
El asistente te pide título, descripción, IOCs; todas las entidades creadas quedan automáticamente etiquetadas con el evento. No te olvides de añadir TLP:CLEAR antes de publicar.
Feeds/Otras fuentes

Sync Actions → List Feeds. Activa alguno gratuito, como “CIRCL OSINT Feed”:
Edita el feed, marca “Enabled”, “Delta Merge = Merge with existing”, Target Tag = TLP:CLEAR.
Hacé clic en “Fetch and store all feed data“ y luego “Push all feed data” para importarlo al event store local.
Cada feed crea eventos en la pestaña Events; puedes re-etiquetar o borrar antes de publicar.
Asegurar tag TLP:CLEAR

Cuando creás o importás un evento, ve a la vista del evento → botón “Tags” → escribe TLP:CLEAR → Enter.
Para añadirlo automáticamente vía feed, configura Target Tag o Tag Event en la definición del feed.
Confirmar en MISP

Events → List Events debería mostrar al menos un evento publicado con TLP:CLEAR.
Desde ese listado, comprobá que el icono de candado está abierto (publicado) y que el campo “Tag” incluye TLP:CLEAR.
Ingesta en OpenCTI

El conector MISP corre cada hora (CONNECTOR_MISP_DURATION_PERIOD=PT1H). Para forzar:
docker logs -f ti-connector-misp-1
Verás Fetching MISP events… seguido de Imported X events.
En OpenCTI: Data → Ingestion → Monitoring ahora muestra MISP. Haz clic y revisa “Last Run” y “Last Event”.
Los eventos importados aparecen en Data → Entities → Reports y Threats → Indicators. Usa Filters → Created by = MISP.
Tips de población adicional

Cargá CSV/STIX existentes en MISP: Event Actions → Import from STIX o Upload sample.
Usa módulos de “Sync” (por ejemplo Sync Actions → List Instances) si querés traerte contenido de otro MISP remoto.
Automatizá la carga con PyMISP: crea un script que llame a /events/add con tus IOCs; siempre recuerda incluir Tag="TLP:CLEAR".
Con al menos un evento publicado + tag correcto, el conector OpenCTI va a detectar cambios y poblar el grafo. Si querés que la importación sea más agresiva (por ejemplo, traer sólo eventos nuevos de la última semana), ajustá MISP_IMPORT_FROM_DATE en .env.

