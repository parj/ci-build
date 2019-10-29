#!/bin/bash

set -e

IMAGE_NAME="encryptkeycircleci"
DOCKER_NAME="${IMAGE_NAME}_tmp"
SECRET_KEY="secret-private-key"

main() {
    init
    prerequisites
    check_errs $? "Pre-requisites does not exist"
    parseArgs "$@"
    buildDockerContainer
    check_errs $? "Unable to build Docker container"
    runDockerContainer
    check_errs $? "Unable to run docker container"
    copyFromDockerContainerAndZip
    check_errs $? "Unable to copy from docker container"
    stopAndRemoveDockerContainer
    check_errs $? "Unable to stop and remove docker container"
}

init() {
    echo "Importing common.sh"
    . ../common.sh
    echoColour "GREEN" "Starting..."
}

function usage() {
    cat <<EOF
This is used to encrypt a file using OpenSSL. Aimed for CircleCI. 

The process uses Docker to pull down the exact image used by CircleCI to encrypt the file and then zip it up for distribution.

./encodeKeys.sh {<option>} --file filename

Available options:
    -h / --help             This message
    -f / --file             The private key file to encrypt
    -k / --key              The paraphrase to encrypt the key

EOF
}

function parseArgs() {
    while (( "$#" )); do
        case "$1" in
            -f|--file)
                FILE=$2
                shift 2
                ;;
            -k|--key)
                KEY=$2
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                shift
                ;;
            --) # end argument parsing
                shift
                break
                ;;
            -*|--*=) # unsupported flags
                echo "Error: Unsupported flag $1" >&2
                exit 1
                ;;
            *) # preserve positional arguments
                PARAMS="$PARAMS $1"
                shift
                ;;
        esac
    done

    if [[ -z $FILE ]] || [[ -z $KEY ]]; then
        echoColour "RED" "File to encrypt and Key paraphrase must both be provided. "
        usage
        echoColour "RED" "File to encrypt and Key paraphrase must both be provided. "
        exit 1
    fi
}

function prerequisites() {
    echoColour "YELLOW" "Checking if docker exists"
    path_to_docker=$(which docker)
    if [ -x "$path_to_docker" ] ; then
        echoColour "GREEN" "FOUND: $path_to_docker"
    else
        echoColour "RED" "NOT FOUND: docker"
        RC=127
    fi
}

function buildDockerContainer() {
    echoColour "YELLOW" "Building container"
    docker build -t ${IMAGE_NAME}:1.0 . --build-arg KEY=${KEY} --build-arg FILE=${FILE}
}

function runDockerContainer() {
    echoColour "YELLOW" "Running container"
    docker run -d --name=${DOCKER_NAME} ${IMAGE_NAME}:1.0
}

function copyFromDockerContainerAndZip() {
    echoColour "YELLOW" "Copying files across"
    docker cp ${DOCKER_NAME}:/tmp/${SECRET_KEY} .
    zip ${SECRET_KEY}.zip ${SECRET_KEY}
    rm ${SECRET_KEY}
}

function stopAndRemoveDockerContainer() {
    echoColour "YELLOW" "Removing containers"
    docker stop ${DOCKER_NAME}
    docker rm -f ${DOCKER_NAME}
}



main "$@"