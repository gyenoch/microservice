resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.large"
  subnet_id                   = aws_subnet.public[1].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_tls.id]
  #security_groups             = [aws_security_group.allow_tls.name]
  key_name = "hipstershop"
  #user_data = file("bootstrap.sh")

  iam_instance_profile = aws_iam_instance_profile.bootstrap_node_instance_profile.name

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = "30"
  }

  tags = {
    Name = "JumpServer"
  }

  depends_on = [aws_eks_node_group.spot,
    data.aws_eks_cluster.eks_ready,
    aws_eks_cluster.eks,
    aws_iam_openid_connect_provider.eks-oidc,
    aws_eks_addon.example
  ]
}


resource "null_resource" "run_bootstrap" {
  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/home/ubuntu/bootstrap.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("<path-to-your-instance-key.pem>")
      host        = aws_instance.web.public_ip
    }
  }

  provisioner "file" {
    source      = ".env"
    destination = "/home/ubuntu/.env"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("<path-to-your-instance-key.pem>")
      host        = aws_instance.web.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/bootstrap.sh",
      "/home/ubuntu/bootstrap.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("<path-to-your-instance-key.pem>")
      host        = aws_instance.web.public_ip
    }
  }

  depends_on = [aws_instance.web]
}