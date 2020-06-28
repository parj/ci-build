[![CircleCI](https://circleci.com/gh/parj/ci-build.svg?style=svg)](https://circleci.com/gh/parj/ci-build) ![GitHub](https://img.shields.io/github/license/parj/ci-build)

# What is this?

This is a repository to hold a simple step of Java CI scripts. The scripts can be used on TravisCI or CircleCI (or even Jenkins!).

The steps ths script goes through:

- Decrypt and import your gpg keys
- Building a snapshot image if the branch is not `release` and publishing docker image to docker hub
- Building a release image if the branch is `release` and publishing docker image to docker hub

# How do I use this?

In the root folder of your repository add the following

```shell
    git submodule add https://github.com/parj/ci-build .ci
```

This adds a submodule to your repository under the directory .ci

An example CircleCI `config.yml` for Java

```yaml
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
        
            - run: 
                name: Perform a java build
                command: .ci/build.sh

    workflows:
        version: 2
        build_and_test:
            jobs:
            - build
```

An example TravisCI `.travis.yml`

```yaml
    language: java
    jdk:
    - openjdk11

    script: ".ci/build.sh"
```

## How to encode keys for CircleCI

Sensitive files for CircleCI should be encrypted via OpenSSL. CircleCI uses a specific version of OpenSSL. Instead of installing this version manually, it is simpler to download the Docker image and encrypt the file directly on it.

A simple script has been done to achieve that. In `encodePrivateKey`, there is a script called `encodeKeys.sh` to achieve this.

To encrypt call 

```shell
    ./encodeKeys.sh --file gpg-private-key.asc --key AVERYSECUREANDRANDOMPASSWORD
```

The script will provide a file called `secret-private-key.zip` which can then be included in the repo