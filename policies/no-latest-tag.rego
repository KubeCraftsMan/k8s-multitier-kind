package main

deny contains msg if {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("❌ Container '%s' uses :latest tag: %s", [container.name, container.image])
}

deny contains msg if {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not contains(container.image, ":")
  msg := sprintf("❌ Container '%s' has no tag (defaults to :latest): %s", [container.name, container.image])
}
