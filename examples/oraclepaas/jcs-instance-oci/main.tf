variable user {}
variable password {}
variable domain {}

variable object_storage_user {}
variable object_storage_bucket {}
variable swift_password {}

variable tenancy {}
variable tenancy_ocid {}
variable region {}
variable compartment_ocid {}

variable user_ocid {}
variable private_key_path {}
variable fingerprint {}

provider "oraclepaas" {
  user            = "${var.user}"
  password        = "${var.password}"
  identity_domain = "${var.domain}"
  java_endpoint   = "https://jaas.oraclecloud.com"
}

provider "oci" {
  tenancy_ocid     = "${var.tenancy_ocid}"
  user_ocid        = "${var.user_ocid}"
  fingerprint      = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
  region           = "${var.region}"
}

data "terraform_remote_state" "database" {
  backend = "local"

  config {
    path = "../dbcs-instance-oci/terraform.tfstate"
  }
}

locals {
  java_service_name   = "my-terraformed-java-service-oci"
  jcs_backup_bucket   = "${var.object_storage_bucket}"
  AD                  = 1
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[local.AD],"name")}"
  subnet_id           = "${data.terraform_remote_state.database.database_subnet_id}"
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

resource "oraclepaas_java_service_instance" "jcs" {
  name        = "${local.java_service_name}"
  description = "Created by Terraform"

  edition                = "EE"            // SE EE SUITE
  service_version        = "12cRelease212" // 12cRelease212 or 12cR3 or 11gR1
  metering_frequency     = "HOURLY"        // HOURLY MONTHLY
  bring_your_own_license = true

  ssh_public_key = "${file("~/.ssh/id_rsa.pub")}"

  # OCI Settings
  region              = "${var.region}"
  availability_domain = "${local.availability_domain}"
  subnet              = "${local.subnet_id}"

  weblogic_server {
    shape = "VM.Standard2.1"

    database {
      name     = "${data.terraform_remote_state.database.database_service_name}"
      username = "sys"
      password = "Pa55_Word"
    }

    admin {
      username = "weblogic"
      password = "Weblogic_1"
    }
  }

  backups {
    cloud_storage_container = "https://swiftobjectstorage.${var.region}.oraclecloud.com/v1/${var.tenancy}/${local.jcs_backup_bucket}"
    cloud_storage_username  = "${var.object_storage_user}"
    cloud_storage_password  = "${var.swift_password}"
  }
}
