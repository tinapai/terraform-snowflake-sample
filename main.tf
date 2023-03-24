terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.35"
    }
  }
}

provider "snowflake" {
  role  = "SYSADMIN"
}

resource "snowflake_database" "db" {
  name     = "TF_DEMO"
}

resource "snowflake_warehouse" "warehouse" {
  name           = "TF_DEMO"
  warehouse_size = "xsmall"

  auto_suspend = 60
}

provider "snowflake" {
    alias = "security_admin"
    role  = "SECURITYADMIN"
}

resource "snowflake_role" "role" {
    provider = snowflake.security_admin
    name     = "TF_DEMO_SVC_ROLE"
}

resource "snowflake_database_grant" "grant" {
    provider          = snowflake.security_admin
    database_name     = snowflake_database.db.name
    privilege         = "USAGE"
    roles             = [snowflake_role.role.name]
    with_grant_option = false
}

resource "snowflake_schema" "schema" {
    database   = snowflake_database.db.name
    name       = "TF_DEMO"
    is_managed = false
}

resource "snowflake_schema_grant" "grant" {
    provider          = snowflake.security_admin
    database_name     = snowflake_database.db.name
    schema_name       = snowflake_schema.schema.name
    privilege         = "USAGE"
    roles             = [snowflake_role.role.name]
    with_grant_option = false
}

resource "snowflake_warehouse_grant" "grant" {
    provider          = snowflake.security_admin
    warehouse_name    = snowflake_warehouse.warehouse.name
    privilege         = "USAGE"
    roles             = [snowflake_role.role.name]
    with_grant_option = false
}

resource "tls_private_key" "svc_key" {
    algorithm = "RSA"
    rsa_bits  = 2048
}

resource "snowflake_user" "user" {
    provider          = snowflake.security_admin
    name              = "tf_demo_user"
    default_warehouse = snowflake_warehouse.warehouse.name
    default_role      = snowflake_role.role.name
    default_namespace = "${snowflake_database.db.name}.${snowflake_schema.schema.name}"
    rsa_public_key    = substr(tls_private_key.svc_key.public_key_pem, 27, 398)
}

resource "snowflake_role_grants" "grants" {
    provider  = snowflake.security_admin
    role_name = snowflake_role.role.name
    users     = [snowflake_user.user.name]
}


resource "snowflake_sequence" "sequence" {
  database = snowflake_schema.schema.database
  schema   = snowflake_schema.schema.name
  name     = "sequence"
}

resource "snowflake_table" "table" {
  database            = snowflake_schema.schema.database
  schema              = snowflake_schema.schema.name
  name                = "table"
  comment             = "A table."
  cluster_by          = ["to_date(DATE)"]
  data_retention_days = snowflake_schema.schema.data_retention_days
  change_tracking     = false

  column {
    name     = "id"
    type     = "int"
    nullable = true

    default {
      sequence = snowflake_sequence.sequence.fully_qualified_name
    }
  }

  column {
    name     = "identity"
    type     = "NUMBER(38,0)"
    nullable = true

    identity {
      start_num = 1
      step_num  = 3
    }
  }

  column {
    name     = "data"
    type     = "text"
    nullable = false
  }

  column {
    name = "DATE"
    type = "TIMESTAMP_NTZ(9)"
  }

  column {
    name    = "extra"
    type    = "VARIANT"
    comment = "extra data"
  }

}
