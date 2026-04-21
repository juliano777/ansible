terraform {
    required_providers {
      podman = { source = "containers/podman" }
    }
}

provider "podman" {}

# Create a PostgreSQL container
resource "postgresql_container" "postgres" {
    name = "pg-tofu"
    image = "docker.io/library/postgres"

    # Environment variables for PostgreSQL
    env = {
        PGUSER = "admin"
        PGPASSWORD = "123"
        PGDATABASE = "db_app"
    }

    # Export PostgreSQL port
    ports {
        internal = 5432
        external = 5432
    }

    # Persist data using a volume
    /*
    volume {
        host_path = "/tmp/data"
        container_path = "/var/lib/postgresql/data"
    }
    */
}