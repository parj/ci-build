#!/bin/bash

set -e
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

function main() {
    init
    check_errs $? "Init did not succeed"
    setup_git
    check_errs $? "Git setup did not succeed "
}

function timestamp() {
    date +"%Y-%m-%d %H:%M:%S,%3N"
}

function usage() {
    cat <<EOF
This is used for running CI builds. 

Available options:
    -h / --help             This message

EOF
    exit 0
}

init() {
    echoColour "GREEN" "Starting..."
}

setup_git() {
    echoColour "GREEN" "Setting up git"
    git config --global user.email "ci@io.github.parjanya.org"
    git config --global user.name "CI Build"
}


function parseArgs() {
    while (( "$#" )); do
        case "$1" in
            -h|--help)
                usage
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

function echoColour() {
    local colour=""

    case $1 in
        "RED")
            colour=${RED} 
            ;;
        "YELLOW")
            colour=${YELLOW}
            ;;
        "GREEN")
            colour=${GREEN}
            ;;
        *)
            colour=${NC}
            ;;
    esac
    echo -e "${colour}$(timestamp) $2 ${NC}"

}

function check_errs() {
  if [ "${1}" -ne "0" ]; then
    echoColour "RED" "ERROR # ${1} : ${2}"
    exit ${1}
  fi
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
            mvn -B -s .ci/settings.xml release:clean release:prepare -DdryRun=true
        fi

        #Only perform full release on circleci
        if [[ $CIRCLE_BRANCH == "release" ]] && [[ -z $CIRCLE_TAG ]]; then
            exeinf "Performing maven release"
            mvn -B -s .ci/settings.xml release:clean release:prepare release:perform -DscmCommentPrefix="[skip ci] [maven-release-plugin] "

            pushTagsAndCommit
            buildDockerImageFromLatestTag
        fi
    else
        if [[ $TRAVIS == "true" ]]; then
            exeinf "Travis Snapshot build"
            mvn -s .ci/settings.xml package docker:build -Dgpg.skip
        else
            exeinf "Jenkins Snapshot build"
            mvn -s .ci/settings.xml deploy docker:build
        fi
    fi
}

main "$@"