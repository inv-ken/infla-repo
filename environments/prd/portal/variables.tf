# common
variable "pjname" {
  type        = string
  default     = "mc"
  description = "プロジェクト名。"
}
variable "envname" {
  type        = string
  default     = "prd"
  description = "環境名。"
}
# variable "portal_certificate_id" {
#   type        = string
#   default     = "e1b58e68-4248-4825-a037-043cec8c04d7"
#   description = "portal用証明書ID"
# }