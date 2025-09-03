terraform {
  backend "s3" {
    bucket = "file-upload-terraform-state-a67aa6ad"
    key    = "terraform.tfstate"
    region = "eu-north-1"    
  }
}