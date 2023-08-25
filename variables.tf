variable "region1" {
  type        = string
  default     = "canadaeast"
  description = "Region 1 of the AA deployment"
}

variable "region2" {
  type        = string
  default     = "canadacentral"
  description = "Region 2 of the AA deployment"
}

variable "instance_type" {
  type        = string
  default     = "Standard_D8_v5"
  description = "Instance type for the AKS cluster"
}

variable "azure_rg" {
  type        = string
  default     = "anton-rg-aa-aks"
  description = "Resource group to provision the infrastructure"
}
