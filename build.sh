#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
MAVEN_SETTINGS="$DIR/resources/settings.xml"
DRY_RUN=false

function main() {
    init
    check_errs $? "Init did not succeed"
    parseArgs "$@"
    check_errs $? "Parse args did not succeed"
    setup_git
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
    . $DIR/common.sh
    echoColour "GREEN" "Starting..."
}

setup_git() {
    if [[ $CI=="true" ]]; then
        echoColour "GREEN" "Setting up git"
        git config --global user.email "ci@io.github.parjanya.org"
        git config --global user.name "CI Build"
    fi
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
            -i|--import-key)
                decryptAndImportPrivateKeys
                exit $?
                shift
                ;;
            -d|--dry-run)
                echoColour "YELLOW" "-d/--dry-run flagged. Setting release to dry run"
                DRY_RUN="true"
                shift
                ;;
            -s|--settings-file)
                echoColour "GREEN" "-s/--settings-file set. Taking custom settings file $2"
                MAVEN_SETTINGS=$2
                shift 2
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
    unzip -o $DIR/resources/secret-private-key.zip -d $DIR/resources/
    echoColour "YELLOW" "Extracting private gpg key"
    openssl aes-256-cbc -d -in $DIR/resources/secret-private-key -out $DIR/resources/gpg-private-key.asc -k "${PRIVATE_KEY}"
    echoColour "YELLOW" "Importing gpg key"
    gpg --batch --import $DIR/resources/gpg-private-key.asc
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

performMavenRelease() {
    if [[ $DRY_RUN=="true" ]]; then
        echoColour "GREEN" "Running dry run"
        mvn -B -s $MAVEN_SETTINGS release:clean release:prepare -DscmCommentPrefix="[skip ci] [maven-release-plugin] " -DdryRun=true
    else
        echoColour "GREEN" "Performing a full release"
        mvn -B -s $MAVEN_SETTINGS release:clean release:prepare release:perform -DscmCommentPrefix="[skip ci] [maven-release-plugin] "
        pushTagsAndCommit
        buildDockerImageFromLatestTag
    fi
}

buildArtifact() {
    echoColour "YELLOW" "Starting build" 

    if [[ $TRAVIS_BRANCH == "release" ]] || [[ $CIRCLE_BRANCH = "release" ]]; then
        echoColour "YELLOW" "Release build"

         #Skip release build if its a tag build
        if [[ -z $CIRCLE_TAG ]] && [[ -z $TRAVIS_TAG ]]; then
            performMavenRelease
        fi
    else
        #BUG with travis where the GPG sign is not working. Fails with error unknow pin entry mode.
        if [[ $CI == "true" ]] ; then
            echoColour "GREEN" "Snapshot build"
            mvn -s $MAVEN_SETTINGS deploy docker:build -DdryRun=$DRY_RUN
        else
            echoColour "GREEN" "Local Snapshot build"
            mvn install docker:build -DdryRun=$DRY_RUN
        fi
    fi
}

main "$@"