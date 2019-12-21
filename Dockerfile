FROM centos:7

#- set redis version
ENV REDIS_DOWNLOAD_URL http://download.redis.io/releases/redis-5.0.6.tar.gz

#- donwload, compile and install redis
RUN yum install make wget gcc -y && \
    wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL" && \
    mkdir -p /opt/redis && \
    tar -xzf redis.tar.gz -C /opt/redis --strip-components=1 && \
    rm redis.tar.gz && \
    cd /opt/redis && \
    make && make install

#- prepare main redis image
FROM centos:7

#- set devops as maintainer
MAINTAINER pawank.kamboj@gmail.com

#- use in label to set current date-time stamps of image, pass during docker build command, like "--build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
#- we need this because some automation tool use this value to get latest image build time stamp
ARG BUILD_DATE

#- set image label according to OCI image-sepc - https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.url=https://redis.io \
      org.opencontainers.image.title=devops-cache-redis \
      org.opencontainers.image.description="Redis Docker image" \
      org.opencontainers.image.version=5.0.x

#- set work dir
WORKDIR /usr/local/bin

#- copy binary from base build
COPY --from=0 /usr/local/bin .

#- copy config file and startup
COPY etc /data/etc
COPY run.sh /data/run.sh

#- default run mode
ENV REDIS_MODE=master

#- create dir to run redis
RUN groupadd -g 1001 redis && useradd -g redis -u 1001 redis && \
    mkdir -p /data/tmp/ /data/redis/redis /data/redis/sentinel && \
    chown redis:redis /data -R

#- run all with redis user
USER redis

#- startup
ENTRYPOINT ["/data/run.sh"]

#- default to run only standalone master, other options are -> slave and sentinel
CMD ["master"]
