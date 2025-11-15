FROM harvarditsecurity/misp:latest

COPY bootstrap-db.sh /bootstrap-db.sh
RUN chmod +x /bootstrap-db.sh

ENTRYPOINT ["/bootstrap-db.sh"]
