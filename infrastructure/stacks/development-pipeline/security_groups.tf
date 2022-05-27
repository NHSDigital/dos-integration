resource "aws_security_group" "uec_dos_int_int_test_sg" {
  vpc_id      = data.aws_vpc.texas_mgmt_vpc.id
  name        = "${var.project_id}-${var.environment}-int-test-sg"
  description = "Codebuild security group for UEC DoS Int Integration Tests"
  tags = {
    "Service" = "uec-pu"
  }
}

resource "aws_security_group_rule" "allow_all_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.uec_dos_int_int_test_sg.id
}
