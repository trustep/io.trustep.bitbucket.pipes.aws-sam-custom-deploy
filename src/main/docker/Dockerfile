FROM public.ecr.aws/sam/build-provided.al2023:1

# Install dependencies and setup NVM in single layer (curl already available)
RUN curl --proto "=https" --location --output /common.sh https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh && \
    chmod ugo+x /common.sh && \
    curl --proto "=https" --location https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    source ~/.nvm/nvm.sh && \
    nvm install 22

# Copy all application files in single operation
COPY ./pipe/pipe.sh ./LICENSE ./pipe.yml /

# Set permissions
RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]