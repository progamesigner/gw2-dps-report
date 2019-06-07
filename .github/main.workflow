workflow "Build and publish to Docker Hub on push" {
  on = "push"
  resolves = ["Build docker image with tag latest", "Only master branch", "Login to Docker Registry"]
}

action "Only master branch" {
  uses = "actions/bin/filter@3c0b4f0e63ea54ea5df2914b4fabf383368cd0da"
  args = "branch master"
}

action "Login to Docker Registry" {
  uses = "actions/docker/login@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Only master branch"]
  secrets = ["DOCKER_USERNAME", "DOCKER_PASSWORD"]
}

action "Build docker image with tag latest" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Login to Docker Registry"]
  args = "build -t progamesigner/gw2-dps-report:latest ."
}

workflow "Build and publish to Docker Hub on release" {
  on = "release"
  resolves = ["Build docker image with tag"]
}

action "Only tagged release" {
  uses = "actions/bin/filter@3c0b4f0e63ea54ea5df2914b4fabf383368cd0da"
  args = "tag v*"
}

action "Docker Registry" {
  uses = "actions/docker/login@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Only tagged release"]
  secrets = ["DOCKER_USERNAME", "DOCKER_PASSWORD"]
}

action "Build docker image with tag" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Docker Registry"]
  args = "build -t progamesigner/gw2-dps-report:$GITHUB_REF ."
}
