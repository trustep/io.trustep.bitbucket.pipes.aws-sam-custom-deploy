FROM public.ecr.aws/amazonlinux/amazonlinux:2022

# Copy pipe configuration files
COPY ./pipe/pipe.sh /pipe.sh
COPY ./LICENSE /LICENSE
COPY ./pipe.yml /pipe.yml
RUN chmod ugo+x /pipe.sh /pipe.yml

# Install basic linux utilities
RUN yum install -y wget tar gzip zip unzip findutils

# Install Bitbucket Pipes Toolkit for bash
RUN curl -s https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh > /common.sh
RUN chmod ugo+x /common.sh

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install

# Install AWS SAM CLI
RUN wget https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
RUN unzip aws-sam-cli-linux-x86_64.zip -d sam-installation
RUN ./sam-installation/install

# Install Node 16
RUN wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
RUN echo "export NVM_DIR=\"\$([ -z \"\${XDG_CONFIG_HOME-}\" ] && printf %s \"\${HOME}/.nvm\" || printf %s \"\${XDG_CONFIG_HOME}/nvm\")\"" >> ~/.bashrc
RUN echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"" >> ~/.bashrc
RUN . ~/.nvm/nvm.sh && nvm install 16

# Install Unix ODBC Driver from Microsoft package repo
RUN wget --no-verbose https://packages.microsoft.com/rhel/8/prod/unixODBC-2.3.7-1.rh.x86_64.rpm
RUN wget --no-verbose https://packages.microsoft.com/rhel/8/prod/unixODBC-debuginfo-2.3.7-1.rh.x86_64.rpm
RUN wget --no-verbose https://packages.microsoft.com/rhel/8/prod/unixODBC-devel-2.3.7-1.rh.x86_64.rpm
RUN yum install -y unixODBC-2.3.7-1.rh.x86_64.rpm unixODBC-debuginfo-2.3.7-1.rh.x86_64.rpm unixODBC-devel-2.3.7-1.rh.x86_64.rpm

# Install Microsoft SQLServer ODBC Driver
RUN curl https://packages.microsoft.com/config/rhel/8/prod.repo > /etc/yum.repos.d/mssql-release.repo
RUN yum remove unixODBC-utf16 unixODBC-utf16-devel #to avoid conflicts
RUN ACCEPT_EULA=Y yum install -y msodbcsql18
RUN ACCEPT_EULA=Y yum install -y mssql-tools18
RUN echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
RUN source ~/.bashrc

# Setup entry point
ENTRYPOINT ["/pipe.sh"]