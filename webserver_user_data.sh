#!/bin/bash -xe
sudo -su ec2-user 
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
source ~/.bashrc
nvm install 16
nvm use 16
cd ~/
aws s3 cp s3://ahjoesbucket/web-tier/ web-tier --recursive
cd ~/web-tier
npm install 
npm run build
sudo amazon-linux-extras install nginx1 -y
cd /etc/nginx
sudo rm nginx.conf
sudo aws s3 cp s3://ahjoesbucket/nginx.conf /etc/nginx
sudo service nginx restart
chmod -R 755 /home/ec2-user
sudo chkconfig nginx on
