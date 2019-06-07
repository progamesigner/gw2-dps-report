workflow "Build and publish to Docker Hub on push" {
  on = "push"
  resolves = [
    "Only master branch",
    "Build docker image with tag (on push)",
    "Login to Docker Registry (on push)",
    "Push to Docker Hub (on push)",
  ]
}

action "Only master branch" {
  uses = "actions/bin/filter@3c0b4f0e63ea54ea5df2914b4fabf383368cd0da"
  args = "branch master"
}

action "Login to Docker Registry (on push)" {
  uses = "actions/docker/login@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Only master branch"]
  secrets = ["DOCKER_USERNAME", "DOCKER_PASSWORD"]
}

action "Build docker image with tag (on push)" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  args = "build -t $GITHUB_REPOSITORY:latest ."
  needs = ["Only master branch"]
}

action "Push to Docker Hub (on push)" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  args = "push $GITHUB_REPOSITORY:latest"
  needs = ["Login to Docker Registry (on push)", "Build docker image with tag (on push)"]
}

workflow "Build and publish to Docker Hub on release" {
  on = "release"
  resolves = [
    "Only tagged release",
    "Build docker image with tag (on release)",
    "Login to Docker Registry (on release)",
    "Push to Docker Hub (on release)",
  ]
}

action "Only tagged release" {
  uses = "actions/bin/filter@3c0b4f0e63ea54ea5df2914b4fabf383368cd0da"
  args = "tag v*"
}

action "Login to Docker Registry (on release)" {
  uses = "actions/docker/login@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Only tagged release"]
  secrets = ["DOCKER_PASSWORD", "DOCKER_USERNAME"]
}

action "Build docker image with tag (on release)" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  args = "build -t $GITHUB_REPOSITORY:$GITHUB_REF ."
  needs = ["Only tagged release"]
}

action "Push to Docker Hub (on release)" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  args = "push $GITHUB_REPOSITORY:$GITHUB_REF"
  needs = ["Login to Docker Registry (on release)", "Build docker image with tag (on release)"]
}
