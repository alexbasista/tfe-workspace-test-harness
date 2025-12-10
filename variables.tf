variable "random_id_byte_length" {
  type        = number
  description = "Length of bytes per random_id resource."
  default     = 256
}

variable "random_id_resource_count" {
    type        = number
    description = "Number of random_id resources to create within a workspace."
    default     = 100
}