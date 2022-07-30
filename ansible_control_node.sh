#!/bin/bash -xe
sudo apt update -y
sudo apt install -y ansible
sudo apt install python-is-python3
sudo apt-get install python3-pip -y
sudo pip3 install boto
sudo pip3 install boto3
ansible-galaxy collection install amazon.aws