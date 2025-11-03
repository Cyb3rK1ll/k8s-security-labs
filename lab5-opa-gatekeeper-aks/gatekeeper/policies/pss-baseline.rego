package k8spss

violation[{"msg": msg}] {
  input.review.object.kind == "Pod"
  not pss_baseline(input.review.object)
  msg := "Pod violates PSS Baseline"
}

pss_baseline(pod) {
  not pod.spec.containers[_].securityContext.privileged
  not pod.spec.hostNetwork
  not pod.spec.hostPID
  not pod.spec.hostIPC
}
