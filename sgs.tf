

resource "aws_security_group" "Bastion-SG" {
  name        = "Bastion-SG"
  description = "Allow SSH into instances"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "ssh from own ip"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.own_ip[0]]
  }
  ingress {
    description      = "HTTP from WEB"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Bastion host SG"
  }
}

resource "aws_security_group" "web-facing-LB-SG" {
  name        = "web-facing-LB-SG"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "TLS from WEB"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "HTTP from WEB"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web-facing lb sg"
  }
}
resource "aws_security_group" "web-tier-instance-SG" {
  name        = "web-tier sg"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "TLS from WEB"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    security_groups = [aws_security_group.web-facing-LB-SG.id]
  }
  ingress {
    description      = "HTTP from WEB"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups = [aws_security_group.web-facing-LB-SG.id]
  }

  ingress {
    description      = "ssh from Bastion"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups = [aws_security_group.Bastion-SG.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web-tier sg"
  }
}

resource "aws_security_group" "internal-LB-SG" {
  name        = "internal LB-SG"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "TLS from WEB"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    security_groups = [aws_security_group.web-tier-instance-SG.id]
  }
  ingress {
    description      = "HTTP from WEB"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups = [aws_security_group.web-tier-instance-SG.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "internal-lb sg"
  }
}

resource "aws_security_group" "app-tier-instance-SG" {
  name        = "app-tier sg"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description      = "SSH from bastion"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups = [aws_security_group.Bastion-SG.id]
  }
  ingress {
    description      = "Datagram from LB"
    from_port        = 4000
    to_port          = 4000
    protocol         = "tcp"
    security_groups = [aws_security_group.internal-LB-SG.id]
  }
  ingress {
    description      = "Datagram from own ip"
    from_port        = 4000
    to_port          = 4000
    protocol         = "tcp"  
    cidr_blocks      = [var.own_ip[0]]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "app-tier sg"
  }
}

resource "aws_security_group" "DB-SG" {
  name        = "DB sg"
  description = "Allow 3306"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description      = "DB SG"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups = [aws_security_group.app-tier-instance-SG.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "DB sg"
  }
}
