FROM public.ecr.aws/sam/build-provided.al2023:1

# Install dependencies and setup NVM in single layer
RUN dnf install wget -y && \
    wget --no-verbose --output-document=/common.sh https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh && \
    chmod ugo+x /common.sh && \
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    source ~/.nvm/nvm.sh && \
    nvm install 22 && \
    dnf clean all

# Copy all application files in single operation
COPY ./pipe/pipe.sh ./LICENSE ./pipe.yml /

# Set permissions
RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]