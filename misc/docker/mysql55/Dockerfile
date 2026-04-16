FROM debian/eol:jessie

ARG MYSQL_VERSION=5.5.47
ARG MYSQL_DOWNLOAD_URL=https://downloads.mysql.com/archives/get/p/23/file/mysql-5.5.47-linux2.6-x86_64.tar.gz

RUN printf '%s\n' \
    'deb http://archive.debian.org/debian jessie main' \
    'deb http://archive.debian.org/debian-security jessie/updates main' \
    > /etc/apt/sources.list \
    && printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99no-check-valid-until

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        libaio1 \
        libncurses5 \
        perl \
        procps \
        psmisc \
        tar \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r mysql \
    && useradd -r -g mysql -s /bin/false mysql \
    && mkdir -p /opt /var/lib/mysql /var/run/mysqld \
    && curl -fsSL "${MYSQL_DOWNLOAD_URL}" -o /tmp/mysql.tar.gz \
    && tar -xzf /tmp/mysql.tar.gz -C /opt \
    && mv "/opt/mysql-${MYSQL_VERSION}-linux2.6-x86_64" /opt/mysql \
    && test -x /opt/mysql/bin/my_print_defaults \
    && test -x /opt/mysql/scripts/mysql_install_db \
    && test -x /opt/mysql/bin/mysqld_safe \
    && ln -s /opt/mysql /usr/local/mysql \
    && rm /tmp/mysql.tar.gz \
    && chown -R mysql:mysql /opt/mysql /var/lib/mysql /var/run/mysqld

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
