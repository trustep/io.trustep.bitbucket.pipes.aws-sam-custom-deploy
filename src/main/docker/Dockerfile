FROM public.ecr.aws/sam/build-provided:1

RUN ["/bin/bash", "-c", "yum install wget -y && wget --no-verbose --output-document=/common.sh https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh && chmod ugo+x /common.sh"]
RUN ["/bin/bash", "-c", "wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash && source ~/.nvm/nvm.sh && nvm install 16"]


# RUN 
# RUN echo "export NVM_DIR=\"\$([ -z \"\${XDG_CONFIG_HOME-}\" ] && printf %s \"\${HOME}/.nvm\" || printf %s \"\${XDG_CONFIG_HOME}/nvm\")\"" >> ~/.bashrc
# RUN echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"" >> ~/.bashrc
# RUN . ~/.nvm/nvm.sh && nvm install 16



COPY ./pipe/pipe.sh /pipe.sh
COPY ./LICENSE /LICENSE
COPY ./pipe.yml /pipe.yml

RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]