FROM proxysql/proxysql:VERSION

RUN apt update && apt -y install mysql-client && apt clean all

ENTRYPOINT ["proxysql", "-f", "-D", "/var/lib/proxysql"]

