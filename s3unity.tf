resource "aws_s3_bucket" "unity-assests" {
  bucket = "unity-webgl-deployment"

  tags = {
    Name        = ""
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_website_configuration" "http-config" {
  bucket = aws_s3_bucket.unity-assests.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

}
