ARG POSTGRES_VERSION=17

FROM buildpack-deps:bookworm
ARG POSTGRES_VERSION

RUN install -d /usr/share/postgresql-common/pgdg
RUN curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update && apt-get -y install postgresql-server-dev-$POSTGRES_VERSION

WORKDIR /build
ADD . .

RUN make

FROM postgres:$POSTGRES_VERSION-bookworm
ARG POSTGRES_VERSION

COPY --from=0 /build/ensure_role_and_database_exists.so /usr/lib/postgresql/$POSTGRES_VERSION/lib/ensure_role_and_database_exists.so
