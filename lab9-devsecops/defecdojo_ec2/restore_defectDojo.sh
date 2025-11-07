mkdir -p ~/backups
cd ~/backups
aws s3 cp s3://defectdojo-backup-lab9-devsecops/defectdojo_db_backup_2025-11-06_2313.sql .
aws s3 cp s3://defectdojo-backup-lab9-devsecops/dojo_media_backup_2025-11-06_2313.tar.gz .

sudo docker exec -i django-defectdojo-postgres-1 psql -U defectdojo defectdojo < defectdojo_db_backup_2025-11-06_2313.sql

sudo docker cp dojo_media_backup_2025-11-06_2313.tar.gz django-defectdojo-nginx-1:/usr/share/nginx/html/
sudo docker exec -it django-defectdojo-nginx-1 bash -c "cd /usr/share/nginx/html && tar -xzf dojo_media_backup_2025-11-06_2313.tar.gz && rm dojo_media_backup_2025-11-06_2313.tar.gz"

sudo docker compose restart
sudo docker compose ps