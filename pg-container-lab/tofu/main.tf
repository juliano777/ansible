terraform {
  required_providers {
    podman = {
      source  = "containers/podman"
    }
  }
}

provider "podman" {
  uri = "unix:///run/podman/podman.sock"
}

# Create a PostgreSQL container
resource "podman_container" "postgres" {
  name  = "pg-tofu"
  image = "docker.io/library/postgres:16"

  # Environment variables for PostgreSQL
  env = {
    POSTGRES_USER     = "admin"
    POSTGRES_PASSWORD = "123"
    POSTGRES_DB       = "db_app"
  }

  # Expose PostgreSQL port
  ports {
    internal = 5432
    external = 5432
  }

  # Persist data using a volume
  volume {
    host_path      = "/tmp/data"
    container_path = "/var/lib/postgresql/data"
  }
}