terraform {
  backend "s3" {
      bucket = "my-techops-test-bucket"
      key = "techops/test/state"
      region = "us-west-2"
  }
}