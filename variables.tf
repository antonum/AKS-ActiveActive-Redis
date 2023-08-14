variable "region1" {
  type        = string
  default     = "eastus"
  description = "Region 1 of the AA deployment"
}

variable "region2" {
  type        = string
  default     = "canadacentral"
  description = "Region 2 of the AA deployment"
}

variable "instance_type" {
  type        = string
  default     = "Standard_D4_v5"
  description = "Instance type for the AKS cluster"
}
