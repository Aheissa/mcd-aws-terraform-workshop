terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.42.0"
    }
    ciscomcd = {
      source  = "CiscoDevNet/ciscomcd"
      version = "0.2.5"
    }
  }
}

resource "aws_key_pair" "us_key" {
  key_name   = "mcd-lab"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_key_pair" "eu_key" {
  provider   = aws.eu
  key_name   = "mcd-lab"
  public_key = file("~/.ssh/id_rsa.pub")
}
