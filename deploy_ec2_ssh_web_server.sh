#!/bin/bash

# Global Settings
account="default"
region="us-east-2"
 
# Instance settings/parameters
image_id="ami-916f59f4" # ubuntu 16.04 LTS 64 bit
ssh_key_name="deploykeypair"
instance_type="t2.micro"
subnet_id="subnet-5b3a7416"
root_vol_size=8
count=1
security_groups=default
 
#Deploy Instance
echo "creating new Ubuntu Server 16.04 LTS $instance_type using $image_id"
instance_id=$(aws ec2 run-instances --region $region --key-name $ssh_key_name --instance-type $instance_type --image-id $image_id --count $count --subnet-id $subnet_id --security-groups $security_group --block-device-mapping "[ { \"DeviceName\": \"/dev/sda1\", \"Ebs\": { \"VolumeSize\": $root_vol_size } } ]" --query 'Instances[*].InstanceId' --output text)
 
echo "$instance_id created"

#Waiting for the instance to leave the pending state
while state=$(aws ec2 describe-instances --instance-ids $instance_id --output text --query 'Reservations[*].Instances[*].State.Name'); test "$state" = "pending"; do
  sleep 1; echo -n '.'
done; echo " $state"

#Getting IP address of the running instance:
ip_address=$(aws ec2 describe-instances --instance-ids $instance_id --output text --query 'Reservations[*].Instances[*].PublicIpAddress')
echo ip_address=$ip_address

#Storing instance data
echo "Storing instance data"
echo "aws ec2 describe-instances --profile $account --region $region --instance-ids $instance_id" > $instance_id-details.json

#Creating Termination Script
echo "create termination script"
echo "#!/bin/bash" > terminate-instance.sh
echo "aws ec2 terminate-instances --profile $account --region $region --instance-ids $instance_id" >> terminate-instance.sh
chmod +x terminate-instance.sh

#Getting the ssh host key fingerprints to compare at ssh time 
#It may take a few minutes for output to be available
aws ec2 get-console-output --instance-id $instance_id --output text | perl -ne 'print if /BEGIN SSH .* FINGERPRINTS/../END SSH .* FINGERPRINTS/'

#SSH to the instance
#It will promopt for Yes/No, when SSH connection is established
#Remotely perform system update, deploy Apache server and "Hello World" webpage
ssh -i ./$ssh_key_name.pem ubuntu@$ip_address <<EOT

#!/bin/bash

sudo apt-get update -y
sudo apt-get install apache2 -y
sudo service apache2 start
sudo apt-get install sysv-rc-conf -y
sudo sysv-rc-conf apache2 on
sudo chmod 777 -R /var/www/html
sudo echo "Hello World" > /var/www/html/index.html

EOT

 echo "## Say Ta-Da!!! Scripts has completed."
