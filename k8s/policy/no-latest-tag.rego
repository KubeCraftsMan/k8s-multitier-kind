package main

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg = sprintf("❌ POLICY VIOLATION: Container '%s' uses forbidden ':latest' tag! Image: %s", [container.name, container.image])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not contains(container.image, ":")
  msg = sprintf("❌ POLICY VIOLATION: Container '%s' has no image tag (defaults to :latest)! Image: %s", [container.name, container.image])
}
