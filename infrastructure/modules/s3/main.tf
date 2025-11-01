#tfsec:ignore:aws-s3-enable-bucket-logging
#tfsec:ignore:aws-s3-block-public-policy
#tfsec:ignore:aws-s3-ignore-public-acls
#tfsec:ignore:aws-s3-restrict-public-buckets
#tfsec:ignore:aws-s3-no-public-buckets
#tfsec:ignore:aws-s3-block-public-acls
#tfsec:ignore:aws-s3-no-public-buckets
#tfsec:ignore:aws-s3-specify-public-access-block
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.8.2"
  bucket  = var.name
  acl     = var.acl

  // S3 bucket-level Public Access Block configuration
  block_public_acls                     = true
  block_public_policy                   = true
  ignore_public_acls                    = true
  restrict_public_buckets               = true
  attach_deny_insecure_transport_policy = true

  force_destroy = var.force_destroy

  attach_policy = var.attach_policy
  policy        = var.policy

  logging                  = var.logging
  control_object_ownership = var.control_object_ownership
  object_ownership         = var.object_ownership

  versioning = {
    enabled = var.versioning_enabled
  }

  server_side_encryption_configuration = var.server_side_encryption_configuration

  lifecycle_rule = [{
    id      = "transition-to-infrequent-access-storage"
    enabled = var.lifecycle_infrequent_storage_transition_enabled

    prefix = var.lifecycle_infrequent_storage_object_prefix

    transition = [{
      days          = var.lifecycle_days_to_infrequent_storage_transition
      storage_class = "STANDARD_IA"
    }]
    },
    {
      id      = "transition-to-glacier"
      enabled = var.lifecycle_glacier_transition_enabled

      prefix = var.lifecycle_glacier_object_prefix

      transition = [{
        days          = var.lifecycle_days_to_glacier_transition
        storage_class = "GLACIER"
      }]
    },
    {
      id      = "expire-objects"
      enabled = var.lifecycle_expiration_enabled

      prefix = var.lifecycle_expiration_object_prefix

      expiration = {
        days = var.lifecycle_days_to_expiration
      }
    }
  ]
}
