FROM public.ecr.aws/sam/build-provided

RUN yum install wget -y

COPY ./pipe/pipe.sh /pipe.sh
COPY ./LICENSE /LICENSE
COPY ./pipe.yml /pipe.yml
RUN wget --no-verbose --output-document=/common.sh https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh

RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]