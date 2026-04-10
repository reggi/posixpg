FROM postgres:15-bullseye

RUN apt-get update \
    && apt-get install -y sudo apache2-utils jq wget \
    && wget -O /usr/bin/yq https://github.com/mikefarah/yq/releases/download/v4.43.1/yq_linux_amd64 \
    && chmod +x /usr/bin/yq \
    && rm -rf /var/lib/apt/lists/*

# Configure sudo to not require a password
RUN echo "ALL ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
# 1) Make adduser create homes with 0755 instead
#    of 0700

ENV DEFAULT_DIR_MODE=755

RUN sed -i "s|^#DIR_MODE=.*|DIR_MODE=${DEFAULT_DIR_MODE}|" /etc/adduser.conf

ENV POSTGRES_DB=memex
ENV POSTGRES_USER=postgres
ENV POSTGRES_HOST=localhost
ENV POSTGRES_PORT=5432

# Copy utility scripts and SQL folders into bin
COPY sql /usr/local/bin/sql
COPY spec /usr/local/bin/spec

# Ensure scripts are executable
RUN chmod +x /usr/local/bin/*
RUN mkdir -p /usr/local/bin/debi /usr/local/bin/mmex

# memex envs
ENV BCRYPT_PEPPER="123456789"
ENV DEFAULT_HOME_DIR="/home"

RUN echo '"\e[A": history-search-backward' >> /root/.inputrc
RUN echo '"\e[B": history-search-forward'  >> /root/.inputrc
