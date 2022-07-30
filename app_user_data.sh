#!/bin/bash -xe
sudo su ec2-user
sudo yum install mysql -y
sudo curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
sudo source ~/.bashrc
sudo nvm install 16
sudo nvm use 16
sudo npm install -g pm2   
cd ~/
aws s3 cp s3://ahjoesbucket/app-tier/ app-tier --recursive
cd ~/app-tiercd ~
npm install
pm2 start index.js
pm2 list
sudo env PATH=$PATH:/home/ec2-user/.nvm/versions/node/v16.16.0/bin /home/ssm-user/.nvm/versions/node/v16.16.0/lib/node_modules/pm2/bin/pm2 startup systemd -u ec2-user --hp /home/ec2-user
pm2 save

