mkdir -p ~/backups
cd ~/backups

docker exec -t django-defectdojo-postgres-1 \
  pg_dumpall -c -U defectdojo > defectdojo_db_backup_$(date +%F_%H%M).sql

docker run --rm \
  -v django-defectdojo_django-media:/data \
  -v $(pwd):/backup \
  alpine tar czvf /backup/dojo_media_backup_$(date +%F_%H%M).tar.gz /data


aws s3 cp defectdojo_db_backup_2025-11-06_2313.sql s3://defectdojo-backup-lab9-devsecops/
aws s3 cp dojo_media_backup_2025-11-06_2313.tar.gz s3://defectdojo-backup-lab9-devsecops/