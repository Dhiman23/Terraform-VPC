resource "aws_vpc" "myVPC" {
  cidr_block = var.cidr
}
# here we are creating subnet which are going to reside inside the private VPC sub1
# the allocating this subnet in us-east-1a
resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myVPC.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

# here we are creating subnet which are going to reside inside the private VPC sub2
# the allocating this subnet in us-east-1b
resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myVPC.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}
#creating internate gate (IGW makes the flow to the outer traffic in side the private VPC)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myVPC.id
}
# here we are making route tables (RT helps to route the traffic with is coming from IGW to subnets)

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
# here we are associating RT with the subnets

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id

}
# here we are associating RT with the subnets

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id

}
# here we are making security group 
# ingress means Inbound
# egress means Outbound

resource "aws_security_group" "webSg" {
  name        = "web"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myVPC.id

  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "web-sg"
  }
}

# here we creating s3
resource "aws_s3_bucket" "mybucket" {
  bucket = "terraformawscreation"
}
# creating ec2 instance for sub1
resource "aws_instance" "webserver1" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = base64encode(file("userdata.sh"))
}
# creating ec2 for instance for sub2
resource "aws_instance" "webserver2" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = base64encode(file("userdata1.sh"))
}

# creating ALB layer 7

resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.webSg.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]

}

# creating target group which is on our VPC 
resource "aws_lb_target_group" "tg" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myVPC.id
  health_check {
    path = "/"
    port = "traffic-port"

  }

}
# here we are attaching target group to particular webserver1

resource "aws_lb_target_group_attachment" "attac1" {

  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80

}
# here we are attaching target group to particular webserver2

resource "aws_lb_target_group_attachment" "attac2" {

  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver2.id
  port             = 80

}
# here we are attaching ALB and TargetGroup with help of listener

resource "aws_lb_listener" "listner" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }

}
output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}
