ARG SAM_CLI_VERSION=1.165.0
ARG SAM_BASE_IMAGE=build-provided.al2023
# Las imagenes oficiales SAM build y Bitbucket Pipes esperan root en CI (sam build, nvm, mounts).
# No cambiar a USER no-root sin validar el pipe completo. (Sonar docker:S6471 — aceptado a proposito)
FROM public.ecr.aws/sam/${SAM_BASE_IMAGE}:${SAM_CLI_VERSION}

# Re-declare after FROM so build-args apply to this stage.
ARG INSTALL_NVM=true

# Install Bitbucket pipes toolkit; optionally NVM + Node 22 (custom/default image only).
# NVM install.sh se descarga, verifica SHA-256 y luego se ejecuta (no pipe directo a bash).
ARG NVM_INSTALL_SHA256=8e45fa547f428e9196a5613efad3bfa4d4608b74ca870f930090598f5af5f643
RUN curl --proto "=https" --location --output /common.sh https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh && \
    chmod ugo+x /common.sh && \
    if [ "${INSTALL_NVM}" = "true" ]; then \
      curl --proto "=https" --location --output /tmp/nvm-install.sh \
        https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh && \
      echo "${NVM_INSTALL_SHA256}  /tmp/nvm-install.sh" | sha256sum -c - && \
      bash /tmp/nvm-install.sh && \
      rm -f /tmp/nvm-install.sh && \
      . ~/.nvm/nvm.sh && \
      nvm install 22; \
    fi

# Copy all application files in single operation
COPY ./pipe/pipe.sh ./LICENSE ./pipe.yml /

# Set permissions
RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]
