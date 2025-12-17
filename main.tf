data "external" "test_data_source" {
  program = ["/bin/sh", "-c", "sleep 180 && echo {}"]
}

resource "random_id" "one" {
  count = var.random_id_resource_count

  byte_length = var.random_id_byte_length

  keepers = {
    uuid = uuid()
  }
}

resource "random_id" "two" {
  count = var.random_id_resource_count

  byte_length = var.random_id_byte_length

  keepers = {
    uuid = uuid()
  }
}

resource "random_id" "three" {
  count = var.random_id_resource_count

  byte_length = var.random_id_byte_length

  keepers = {
    uuid = uuid()
  }
}