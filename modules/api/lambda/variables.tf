# common
variable "pjname" {
  type        = string
  default     = "mc"
  description = "プロジェクト名。"
}
variable "envname" {
  type        = string
  default     = "ci"
  description = "環境名。"
}

variable "name" {
  description = "API Name"
  default     = ""
}

variable "kms_key" {
  description = "kms_key_arn"
  default     = ""
}

variable "token" {
  description = "token"
  default     = ""
}

variable "endpoint" {
  description = "endpoint"
  default     = ""
}

variable "vpc-config" {
  description = "vpc-config"
  default     = {}
}