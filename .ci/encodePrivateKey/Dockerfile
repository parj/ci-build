FROM circleci/openjdk:11-jdk

ARG KEY
ARG FILE

COPY --chown=circleci:circleci ["${FILE}", "/tmp/"]

RUN openssl enc -aes-256-cbc -salt -in /tmp/${FILE} -out /tmp/secret-private-key -k ${KEY}

