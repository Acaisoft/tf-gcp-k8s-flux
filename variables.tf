# Parameters authorized:
# version (default: v2.11.0)
# values (default: values.yaml)
# chart-version (default: 0.9.1)
variable "helm" {
  type        = "map"
  description = "Helm provider parameters"
  default     = {}
}

# Parameters authorized:
# project (mandatory)
# region (mandatory)
variable "provider" {
  type        = "map"
  description = "Google provider parameters"
}

# Parameters authorized:
# bucket (mandatory)
# prefix (mandatory)
variable "gke_cluster_remote_state" {
  type        = "map"
  description = "GKE cluster remote state parameters"
}

# Parameters authorized:
# github_url (mandatory)
# slack_channel  (mandatory)
# slack_url (mandatory)
# slack_username (default: "Flux CD")
variable "fluxcloud" {
  type        = "map"
  description = "Flux cloud configuration"
}