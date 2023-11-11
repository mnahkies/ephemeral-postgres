ARG POSTGRES_VERSION=15
FROM buildpack-deps:bullseye
ARG POSTGRES_VERSION

RUN apt-get update && apt-get -y install wget
RUN echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

RUN apt-get update && apt-get -y install postgresql-server-dev-$POSTGRES_VERSION

WORKDIR /build
ADD . .

RUN make

FROM postgres:$POSTGRES_VERSION
ARG POSTGRES_VERSION

COPY --from=0 /build/ensure_role_and_database_exists.so /usr/lib/postgresql/$POSTGRES_VERSION/lib/ensure_role_and_database_exists.so
