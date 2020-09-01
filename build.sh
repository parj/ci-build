#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
MAVEN_SETTINGS="$DIR/resources/settings.xml"
DOCKER_BUILD_PARAMS="jib:build"
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
    -d / --dry-run          Used to dry run releases in maven
    -h / --help             This message
    -i / --importKey        Extracts private key and imports into GPG Keychain
    -s / --settings-file    Used to for provding a custom location for maven settings file - settings.xml
    --skip-docker           Skips building docker image
EOF
    exit 0
}

init() {
    echo "Importing common.sh"
    . $DIR/common.sh
    echoColour "GREEN" "Starting..."
}

setup_git() {
    if [[ $CI == "true" ]]; then
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
            --skip-docker)
                echoColour "GREEN" "--skip-docker set. Skipping docker build"
                DOCKER_BUILD_PARAMS=""
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
    ./importKeys.sh
}

pushTagsAndCommit() {
    echoColour "YELLOW" "Pushing tags"
    git push --tags
    echoColour "YELLOW" "Pushing maven commit"
    git push -u origin release
}

#Required as mvn:release bumps tags
buildDockerImageFromLatestTag() {
    latesttag=$(git describe --tags $(git rev-list --tags --max-count=1))
    echoColour "YELLOW" "Reset git repository"
    git reset --hard
    echoColour "GREEN" "Checking out latest tag ${latesttag}"
    git checkout tags/${latesttag} -b ${latesttag}
    mvn package $DOCKER_BUILD_PARAMS -DskipTests
}

dockerLogin() {
    echoColour "YELLOW" "Logging into docker"
    echo -n ${DOCKER_PASSWORD} | docker login --username ${DOCKER_USERNAME} --password-stdin
    echoColour "GREEN" "Logged into docker"
}

performMavenRelease() {
    if [[ $DRY_RUN == "true" ]]; then
        echoColour "GREEN" "Running dry run"
        mvn -B -s $MAVEN_SETTINGS release:clean release:prepare -DscmCommentPrefix="[skip ci] [maven-release-plugin] " -DdryRun=true
    else
        echoColour "GREEN" "Performing a full release"
        mvn -B -s $MAVEN_SETTINGS release:clean release:prepare release:perform -DscmCommentPrefix="[skip ci] [maven-release-plugin] "
        buildDockerImageFromLatestTag
        pushTagsAndCommit
    fi
}

buildArtifact() {
    echoColour "YELLOW" "Starting build" 
    dockerLogin

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
            
            mvn -s $MAVEN_SETTINGS deploy $DOCKER_BUILD_PARAMS -DdryRun=$DRY_RUN
        else
            echoColour "GREEN" "Local Snapshot build"
            mvn install $DOCKER_BUILD_PARAMS -DdryRun=$DRY_RUN
        fi
    fi
}

main "$@"