ARG SAM_CLI_VERSION=1.165.0
ARG SAM_BASE_IMAGE=build-provided.al2023
FROM public.ecr.aws/sam/${SAM_BASE_IMAGE}:${SAM_CLI_VERSION}

# Re-declare after FROM so build-args apply to this stage.
ARG INSTALL_NVM=true

# Install Bitbucket pipes toolkit; optionally NVM + Node 22 (custom/default image only).
RUN curl --proto "=https" --location --output /common.sh https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh && \
    chmod ugo+x /common.sh && \
    if [ "${INSTALL_NVM}" = "true" ]; then \
      curl --proto "=https" --location https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
      . ~/.nvm/nvm.sh && \
      nvm install 22; \
    fi

# Copy all application files in single operation
COPY ./pipe/pipe.sh ./LICENSE ./pipe.yml /

# Set permissions
RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]
