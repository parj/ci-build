#!/bin/bash

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

function timestamp() {
    date +"%Y-%m-%d %H:%M:%S,%3N"
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