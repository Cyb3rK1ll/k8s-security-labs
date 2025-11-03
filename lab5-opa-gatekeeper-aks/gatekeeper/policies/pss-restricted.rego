package k8spss

violation[{"msg": msg}] {
  input.review.object.kind == "Pod"
  not pss_restricted(input.review.object)
  msg := "Pod violates PSS Restricted"
}

pss_restricted(pod) {
  pss_baseline(pod)
  pod.spec.containers[_].securityContext.runAsNonRoot == true
  not pod.spec.containers[_].securityContext.capabilities
}

pss_baseline(pod) {
  not pod.spec.containers[_].securityContext.privileged
  not pod.spec.hostNetwork
  not pod.spec.hostPID
  not pod.spec.hostIPC
}
