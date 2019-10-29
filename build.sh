#!/bin/bash

set -e

MAVEN_SETTINGS="resources/settings.xml"

function main() {
    init
    check_errs $? "Init did not succeed"
    parseArgs "$@"
    check_errs $? "Parse args did not succeed"
    #setup_git
    check_errs $? "Git setup did not succeed "
    buildArtifact
}

function usage() {
    cat <<EOF
This is used for running CI builds. 

Available options:
    -h / --help             This message
    -i / --importKey        Extracts private key and imports into GPG Keychain
EOF
    exit 0
}

init() {
    echo "Importing common.sh"
    . ./common.sh
    echoColour "GREEN" "Starting..."
}

setup_git() {
    echoColour "GREEN" "Setting up git"
    git config --global user.email "ci@io.github.parjanya.org"
    git config --global user.name "CI Build"
}


function parseArgs() {
    echoColour "YELLOW" "Parsing args"
    while (( "$#" )); do
        case "$1" in
            -h|--help)
                usage
                exit 0
                shift
                ;;
            -i|--importKey)
                decryptAndImportPrivateKeys
                exit $?
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
}

decryptAndImportPrivateKeys() {
    if [[ -z ${PRIVATE_KEY} ]]; then
        echoColour "RED" "Environment variable PRIVATE_KEY was not set. Exiting."
        exit 1
    fi

    echoColour "YELLOW" "Unzipping archive"
    unzip -o resources/secret-private-key.zip -d resources/
    echoColour "YELLOW" "Extracting private gpg key"
    openssl aes-256-cbc -d -in resources/secret-private-key -out resources/gpg-private-key.asc -k "${PRIVATE_KEY}"
    echoColour "YELLOW" "Importing gpg key"
    gpg --batch --import resources/gpg-private-key.asc
    echoColour "GREEN" "List Keys"
    gpg --list-secret-keys
    gpg --list-public-keys
    echoColour "GREEN" "Completed importing key"
}

pushTagsAndCommit() {
    echoColour "YELLOW" "Pushing tags"
    git push --tags
    echoColour "YELLOW" "Pushing maven commit"
    git push -u origin release
}

#Required as mvn:release bumps tags
buildDockerImageFromLatestTag() {
    latesttag=$(git describe --tags)
    echoColour "GREEN" "Checking out latest tags ${latesttag}"
    git checkout ${latesttag}
    mvn package docker:build -DskipTests
}

buildArtifact() {
    echoColour "YELLOW" "Starting build" 

    if [[ $TRAVIS_BRANCH == "release" ]] || [[ $CIRCLE_BRANCH = "release" ]]; then
        echoColour "YELLOW" "Release build"

        #Just do a dry run on TravisCI
        if [[ $TRAVIS_BRANCH == "release" ]]; then
            mvn -B -s $MAVEN_SETTINGS release:clean release:prepare -DdryRun=true
        fi

        #Only perform full release on circleci
        if [[ $CIRCLE_BRANCH == "release" ]] && [[ -z $CIRCLE_TAG ]]; then
            echoColour "YELLOW" "Performing maven release"
            mvn -B -s $MAVEN_SETTINGS release:clean release:prepare release:perform -DscmCommentPrefix="[skip ci] [maven-release-plugin] "

            pushTagsAndCommit
            buildDockerImageFromLatestTag
        fi
    else
        if [[ $TRAVIS == "true" ]]; then
            echoColour "GREEN" "Travis Snapshot build"
            mvn -s $MAVEN_SETTINGS package docker:build -Dgpg.skip
        else
            echoColour "GREEN" "Local Snapshot build"
            mvn -s ../pom.xml install docker:build
        fi
    fi
}

main "$@"