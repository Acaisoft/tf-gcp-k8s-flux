terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "gcs" {}
}
data "terraform_remote_state" "gke_cluster" {
  backend = "gcs"
  config {
    bucket  = "${var.gke_cluster_remote_state["bucket"]}"
    prefix  = "${var.gke_cluster_remote_state["prefix"]}"
  }
}
data "google_client_config" "current" {}

provider "google" {
  region      = "${var.provider["region"]}"
  project     = "${var.provider["project"]}"
}

provider "kubernetes" {
  load_config_file = false

  host                   = "${data.terraform_remote_state.gke_cluster.endpoint}"
  token                  = "${data.google_client_config.current.access_token}"
  cluster_ca_certificate = "${base64decode(data.terraform_remote_state.gke_cluster.cluster_ca_certificate)}"
}

provider "helm" {
  tiller_image = "gcr.io/kubernetes-helm/tiller:${lookup(var.helm, "version", "v2.11.0")}"

  install_tiller = true
  service_account = "${data.terraform_remote_state.gke_cluster.tiller_service_account}"
  namespace = "kube-system"

  kubernetes {
    host                   = "${data.terraform_remote_state.gke_cluster.endpoint}"
    token                  = "${data.google_client_config.current.access_token}"
    cluster_ca_certificate = "${base64decode(data.terraform_remote_state.gke_cluster.cluster_ca_certificate)}"
  }
}

resource "helm_repository" "flux" {
    name = "flux"
    url  = "https://fluxcd.github.io/flux"
}
resource "helm_release" "flux" {
    name      = "flux"
    chart     = "fluxcd/flux"
    version   = "${lookup(var.helm, "chart-version", "0.11.0")}"
    namespace = "flux"
    values = [
        "${file(lookup(var.helm, "values", "values.yaml"))}"
    ]
}

resource "kubernetes_service" "fluxcloud" {
  metadata {
    name = "fluxcloud"
    namespace = "flux"
  }
  spec {
    selector {
      name = "fluxcloud"
    }
    port {
      port = 80
      target_port = 3032
      protocol = "TCP"
    }
  }
  depends_on = ["helm_release.flux"]
}

resource "kubernetes_deployment" "fluxcloud" {
  metadata {
    name = "fluxcloud"
    namespace = "flux"
    labels {
      name = "fluxcloud"
    }
  }
  spec {
    replicas = 1
    strategy {
      type = "RollingUpdate"
    }
    selector {
      match_labels {
        name = "fluxcloud"
      }
    }
    template {
      metadata {
        labels {
          name = "fluxcloud"
        }
      }
      spec {
        container {
          name  = "fluxcloud"
          image = "justinbarrick/fluxcloud:v0.3.4"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = "3032"
          }
          env = [
            {
              name = "SLACK_URL"
              value = "${var.fluxcloud["slack_url"]}"
            },
            {
              name = "SLACK_CHANNEL"
              value = "${var.fluxcloud["slack_channel"]}"
            },
            {
              name = "SLACK_USERNAME"
              value = "${lookup(var.fluxcloud, "slack_username", "Flux CD")}"
            },
            {
              name = "GITHUB_URL"
              value = "${var.fluxcloud["github_url"]}"
            },
            {
              name = "LISTEN_ADDRESS"
              value = ":3032"
            },
          ]
        }
      }
    }
  }
  depends_on = ["helm_release.flux"]
}