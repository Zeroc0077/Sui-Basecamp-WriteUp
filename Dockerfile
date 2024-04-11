FROM postgres:latest

ENV POSTGRES_PASSWORD=postgrespw

ADD init.sql /docker-entrypoint-initdb.d/