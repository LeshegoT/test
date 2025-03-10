# State bucket
terraform {
  backend "s3" {
    bucket  = "heapoverflow-s3-bucket"
    key     = "heapoverflow-s3-bucket/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}