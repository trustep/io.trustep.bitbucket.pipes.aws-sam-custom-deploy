FROM public.ecr.aws/sam/build-provided:1

RUN ["/bin/bash", "-c", "yum install wget -y && wget --no-verbose --output-document=/common.sh https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh"]

COPY ./pipe/pipe.sh /pipe.sh
COPY ./LICENSE /LICENSE
COPY ./pipe.yml /pipe.yml

RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]