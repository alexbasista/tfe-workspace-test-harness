data "external" "test_data_source" {
  program = ["/bin/sh", "-c", "sleep 30 && echo {}"]
}

resource "random_id" "id" {
  byte_length = 256

  keepers = {
    uuid = uuid()
  }
}