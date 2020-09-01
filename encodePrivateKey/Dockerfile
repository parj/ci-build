FROM circleci/openjdk:11-jdk

ARG KEY
ARG FILE

COPY --chown=circleci:circleci ["${FILE}", "/tmp/"]

WORKDIR /tmp

RUN openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -salt -in ${FILE} -out secret-private-key -k ${KEY} && zip secret-private-key.zip secret-private-key

