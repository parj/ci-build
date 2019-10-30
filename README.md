# What is this?

This is a repository to hold a simple step of Java CI scripts. The scripts can be used on TravisCI or CircleCI (or even Jenkins!).

# How do I use this?

In the root folder of your repository add the following

    git submodule add https://github.com/parj/ci-build .ci

This clones this repository into your root under the directory .ci

An example CircleCI `config.yml` for Java

    version: 2
    jobs:
    build:
        docker:
            - image: circleci/openjdk:11-jdk
        
        steps:
            - checkout
            - run: git submodule update --init --recursive

            - run:
                name: Add GPG key
                command: .ci/build.sh -i
        
            - run: .ci/build.sh

    workflows:
        version: 2
        build_and_test:
            jobs:
            - build

An example TravisCI `.travis.yml`

    language: java
    jdk:
    - openjdk11

    script: ".ci/build.sh"


## How to encode keys for CircleCI

Sensitive files for CircleCI should be encrypted via OpenSSL. CircleCI uses a specific version of OpenSSL. Instead of installing this version manually, it is simpler to download the Docker image and encrypt the file directly on it.

A simple script has been done to achieve that. In `encodePrivateKey`, there is a script called `encodeKeys.sh` to achieve this.

To encrypt call 

    ./encodeKeys.sh --file gpg-private-key.asc --key AVERYSECUREANDRANDOMPASSWORD

The script will provide a file called secret-private-key.zip which can then be included in the repo