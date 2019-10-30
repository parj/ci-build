#!./test/libs/bats/bin/bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

@test "Should fail when trying to import key without encryption paraphrase" {
    run ./build.sh -i
    assert_failure
    assert_output -p "Environment variable PRIVATE_KEY was not set."
}

@test "Trigger a local build and check for compile, test, jar, install, docker" {
    run ./build.sh
    assert_failure
    assert_output -p "Building minimalpom 1.0-SNAPSHOT"
    assert_output -p "default-compile"
    assert_output -p "default-test"
    assert_output -p "default-jar"
    assert_output -p "default-install"
    assert_output -p "docker-maven-plugin:0.31.0:build"
}

@test "Trigger a CI build and perform a dry run" {
    
}