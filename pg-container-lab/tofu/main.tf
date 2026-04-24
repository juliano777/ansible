terraform {
  required_providers {
    podman = {
      source  = "registry.terraform.io/decafcode/podman"
      version = "~> 1.1" 
    }
  }
}

# Aqui está o ajuste: container_host no lugar de host
provider "podman" {
  # systemctl --user enable --now podman.socket
  container_host = "unix:///run/user/1000/podman/podman.sock" 
}

resource "podman_image" "debian" {
  reference = "docker.io/library/debian:latest"
}

resource "podman_container" "meu_container" {
  name  = "simples-debian-podman"
  image = podman_image.debian.id
  
  command = ["sleep", "infinity"]
}
