#!/bin/bash 
declare -a instance_list
mapfile -t instance_list < <(aws ec2 run-instances --image-id $1 --count $2 --instance-type $3 --key-name $4 --security-group-ids $5 --subnet-id $6 --associate-public-ip-address --iam-instance-profile Name=$7 --user-data file:///home/controller/Documents/MP-Final-Environment-Setup/install-webserver.sh --output table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")
echo "Waiting for instance/instances ${instance_list[@]} to launch...."
aws ec2 wait instance-running --instance-ids ${instance_list[@]} 
echo "Instance/Instances ${instance_list[@]} up and running...."
aws elb create-load-balancer --load-balancer-name MP1LoadBalancer --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --security-groups $5 --subnets $6
aws elb create-lb-cookie-stickiness-policy --load-balancer-name MP1LoadBalancer --policy-name AravindELBStickyPolicy
aws elb set-load-balancer-policies-of-listener --load-balancer-name MP1LoadBalancer --load-balancer-port 80 --policy-name AravindELBStickyPolicy
aws elb register-instances-with-load-balancer --load-balancer-name MP1LoadBalancer --instances ${instance_list[@]}
aws elb configure-health-check --load-balancer-name MP1LoadBalancer --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3
aws autoscaling create-launch-configuration --launch-configuration-name ITMO-544-launch-config --image-id $1 --key-name $4 --security-groups $5 --instance-type $3 --user-data /home/controller/Documents/MP-Final-Environment-Setup/install-webserver.sh --iam-instance-profile $7
aws autoscaling create-auto-scaling-group --auto-scaling-group-name itmo-544-extended-auto-scaling-group-2 --launch-configuration-name ITMO-544-launch-config --load-balancer-names MP1LoadBalancer --health-check-type ELB --min-size 3 --max-size 6 --desired-capacity 3 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier $6
aws autoscaling put-scaling-policy --auto-scaling-group-name itmo-544-extended-auto-scaling-group-2  --policy-name AravindScalingPolicy --scaling-adjustment 1 --adjustment-type ExactCapacity
aws cloudwatch put-metric-alarm --alarm-name AutoScaleSNSMetric --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold --dimensions "Name=AutoScalingGroup,Value=itmo-544-extended-auto-scaling-group-2" --evaluation-periods 1 --alarm-actions arn:aws:autoscaling:us-west-2:681875787250:scalingPolicy:aeb16e5a-0e52-4eff-aa17-f7f7c5efcbe2:autoScalingGroupName/itmo-544-extended-auto-scaling-group-2:policyName/AravindScalingPolicy arn:aws:sns:us-west-2:681875787250:aravindmp2
aws rds create-db-instance --db-name ITMO544AravindDb --db-instance-identifier ITMO544AravindDb --db-instance-class db.t2.micro --engine MySql --allocated-storage 20 --master-username aravind --master-user-password password --backup-retention-period 1
aws rds create-db-instance-read-replica --db-instance-identifier ITMO544AravindDbReadOnly --source-db-instance-identifier ITMO544AravindDb --db-instance-class db.t2.micro