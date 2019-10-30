#!./test/libs/bats/bin/bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

#NOTE - This test will only succeed if there are no git changes that are staged for commit.
@test "Trigger a CI build and perform a dry run" {
    export TRAVIS_BRANCH="release"
    run ./build.sh --dry-run
    assert_success
    assert_output -p "Building minimalpom 1.0-SNAPSHOT"
    assert_output -p "maven-release-plugin:2.5.3:prepare"
    assert_output -p "Full run would be commit 1 files with message: '[skip ci] [maven-release-plugin] prepare release minimalpom-1.0'"
    assert_output -p "Full run would be tagging working copy"
    assert_output -p "Release preparation simulation complete"
    assert_output -p "BUILD SUCCESS"
}

@test "Should fail when trying to import key without encryption paraphrase" {
    run ./build.sh -i
    assert_failure
    assert_output -p "Environment variable PRIVATE_KEY was not set."
}

@test "Trigger a local build and check for compile, test, jar, install, docker" {
    if [[ -z $CI ]]; then
        unset TRAVIS_BRANCH
    fi

    run ./build.sh
    assert_failure
    assert_output -p "Building minimalpom 1.0-SNAPSHOT"
    assert_output -p "default-compile"
    assert_output -p "default-test"
    assert_output -p "default-jar"
    assert_output -p "default-install"
    assert_output -p "docker-maven-plugin:0.31.0:build"
}

@test "Clean up of release" {
    unset TRAVIS_BRANCH
    run mvn release:clean
    assert_success
}
