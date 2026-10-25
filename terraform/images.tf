# Terraform cannot build Docker images natively, so a script does it.
# Re-runs whenever any file under services/<name> changes.
resource "null_resource" "image" {
  for_each = local.services

  triggers = {
    source_hash = sha1(join("", [
      for f in sort(fileset("${path.module}/../services/${each.key}", "**")) :
      filesha1("${path.module}/../services/${each.key}/${f}")
    ]))
    repository_url = aws_ecr_repository.repo[each.key].repository_url
  }

  provisioner "local-exec" {
    command = "${path.module}/../scripts/build_and_push.sh ${each.key} ${aws_ecr_repository.repo[each.key].repository_url} ${var.aws_region}"
  }

  # Push is allowed by the repo policy, so wait for it.
  depends_on = [aws_ecr_repository_policy.repo]
}
