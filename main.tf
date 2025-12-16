data "external" "test_data_source" {
  program = ["/bin/sh", "-c", "sleep 120 && echo {}"]
}

resource "random_id" "id_1" {
  count = var.random_id_resource_count

  byte_length = var.random_id_byte_length

  keepers = {
    uuid = uuid()
  }
}

resource "random_id" "id_2" {
  count = var.random_id_resource_count

  byte_length = var.random_id_byte_length

  keepers = {
    uuid = uuid()
  }
}