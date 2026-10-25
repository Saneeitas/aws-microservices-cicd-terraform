# NOTE: AWS has stopped offering Cloud9 to new customers; this only works in
# accounts that already have access. Hence it is off by default.
resource "aws_cloud9_environment_ec2" "ide" {
  count = var.create_cloud9 ? 1 : 0

  name                        = "MicroservicesIDE"
  instance_type               = "t3.small"
  image_id                    = "amazonlinux-2-x86_64"
  subnet_id                   = local.public_subnet_ids[0]
  automatic_stop_time_minutes = 60
  connection_type             = "CONNECT_SSH"
}
