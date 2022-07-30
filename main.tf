variable "key_name" {
  type    = string
}

variable "ami_id_master" {
  type    = string
} 

variable "region"{
  type   = string
}

locals {
  common_tags= {
    Owner= "DevOps Team"
    service= "backend"
  }
}


#amazon linux 2 map;
variable "ami_id_managed" {
  type = map(string)
  default = {
    "us-east-1" = "ami-0cff7528ff583bf9a"
    "us-east-2" = "ami-02d1e544b84bf7502"
    "us-west-1" = "ami-0d9858aa3c6322f73"    
    "us-west-2" = "ami-098e42ae54c764c35"
    "ca_central"= "ami-00f881f027a6d74a0"
  }
}

resource "aws_instance" "bastion" {
  ami             = var.ami_id_master #ubuntu ami
  instance_type   = "t2.micro"
  vpc_security_group_ids = [aws_security_group.Bastion-SG.id]
  key_name        = var.key_name
  iam_instance_profile = aws_iam_instance_profile.Ec2-full-access-profile.name
  
  associate_public_ip_address = true
  subnet_id = aws_subnet.pub-subnet-1.id
    tags = {
    Name = "Ansible-Control-Node"
  }
  user_data = filebase64("ansible_control_node.sh")
}



resource "aws_alb" "Web-facing-LB" {
  name               = "web-facing-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-facing-LB-SG.id]
  subnets            = [aws_subnet.pub-subnet-1.id, aws_subnet.pub-subnet-2.id]

  tags = {
    Name = "Public-LB"
  }
}

resource "aws_alb" "App-tier-LB" {
  name               = "private-lb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal-LB-SG.id]
  subnets            = [aws_subnet.priv-subnet-1.id, aws_subnet.priv-subnet-2.id]

  tags = {
    Name = "Private-LB"
  }
}

resource "aws_alb_target_group" "public-lb-tg" {
  name     = "public-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc.id}"
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/health"
    port = 80
  }
}

resource "aws_alb_target_group" "private-lb-tg" {
  name     = "private-lb-tg"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc.id}"
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/health"
    port = 4000
  }
}

resource "aws_alb_listener" "pub-listener_http" {
  load_balancer_arn = "${aws_alb.Web-facing-LB.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.public-lb-tg.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "priv-listener_http" {
  load_balancer_arn = "${aws_alb.App-tier-LB.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.private-lb-tg.arn}"
    type             = "forward"
  }
}


resource "aws_launch_template" "webserver-LT" {
  name = "webserver-LT"

  iam_instance_profile {
    name = aws_iam_instance_profile.Ec2-S3-profile.name
  }
  image_id = var.ami_id_managed[var.region]
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t2.micro"
  key_name = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.web-tier-instance-SG.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-tier instance"
      Env  = "web"
    }
  }
  #user_data = filebase64("webserver_user_data.sh")

}


resource "aws_launch_template" "appserver-LT" {
  name = "appserver-LT"

  iam_instance_profile {
    name = aws_iam_instance_profile.Ec2-S3-profile.name
  }
  image_id = var.ami_id_managed[var.region]
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t2.micro"
  key_name = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.app-tier-instance-SG.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-tier instance"
      Env  = "app"
    }
  }
  #user_data = filebase64("app_user_data.sh")


}

resource "aws_autoscaling_group" "web-asg" {
  name                      = "web-asg"
  max_size                  = 4
  min_size                  = 2
  health_check_grace_period = 300
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.pub-subnet-1.id, aws_subnet.pub-subnet-2.id]
  target_group_arns         = [aws_alb_target_group.public-lb-tg.arn]
  launch_template {
      id = aws_launch_template.webserver-LT.id
     version= "$Latest"
     }

}
resource "aws_autoscaling_group" "app-asg" {
  name                      = "app-asg"
  max_size                  = 4
  min_size                  = 2
  health_check_grace_period = 300
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.priv-subnet-1.id, aws_subnet.priv-subnet-2.id]
  target_group_arns         = [aws_alb_target_group.private-lb-tg.arn]
  launch_template {
      id = aws_launch_template.appserver-LT.id
     version= "$Latest"
     }

}

resource "aws_db_subnet_group" "subnetgroup" {
  name       = "subnetgroup"
  subnet_ids = [aws_subnet.priv-subnet-3.id, aws_subnet.priv-subnet-4.id]
  tags = { Name = "My DB subnet group"}
}

resource "aws_db_instance" "default" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7.31"
  instance_class       = "db.t2.micro"
  db_subnet_group_name = aws_db_subnet_group.subnetgroup.name
  vpc_security_group_ids = [aws_security_group.DB-SG.id]
  db_name               = "mysqldb"
  username             = "joseph"
  password             = "ting1234"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}



provider "aws" {
  region="us-east-1"
}

