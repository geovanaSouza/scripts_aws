#!/bin/bash

security_group_name=SocialBaseSG
key_name=NotebookHome
device_to_volume=/dev/sdf
zone_aws=sa-east-1c

echo Criando VPC
vpc_id=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --output json --query 'Vpc.VpcId' | tr -d '"')
echo VPC ID: ${vpc_id}
echo

echo Criando Internet Gateway
ig_id=$(aws ec2 create-internet-gateway --output json --query 'InternetGateway.InternetGatewayId' | tr -d '"')
echo Internet Gateway ID: ${ig_id}
echo

echo Efetuando attach do Internet Gateway à VPC criada
aws ec2 attach-internet-gateway --internet-gateway-id ${ig_id}  --vpc-id ${vpc_id} --output json
echo

echo Criando sub-rede pública
subnet_id=$(aws ec2 create-subnet --vpc-id ${vpc_id} --cidr-block 10.0.0.0/24 --availability-zone ${zone_aws} --output json --query 'Subnet.SubnetId' | tr -d '"')
echo Subnet ID: $subnet_id
echo

echo Criando tabela de roteamento
route_table_id=$(aws ec2 create-route-table --vpc-id ${vpc_id} --output json --query 'RouteTable.RouteTableId' | tr -d '"')
echo Route Table ID: $route_table_id
echo

echo Criando Rota 
aws ec2 create-route --route-table-id ${route_table_id} --destination-cidr-block 0.0.0.0/0 --gateway-id ${ig_id} --output json
echo

echo Associando a sub-rede à tabela de roteamento
aws ec2 associate-route-table --subnet-id ${subnet_id} --route-table-id ${route_table_id} --output json
echo

echo Criando Grupo de Segurança
sg_id=$(aws ec2 create-security-group --group-name ${security_group_name} --description "Grupo de seguranca SocialBase" --vpc-id ${vpc_id} --output json --query 'GroupId' | tr -d '"')
echo Group ID: $sg_id
echo

echo Criando instância ec2
instance_id=$(aws ec2 run-instances --image-id ami-0fb83963 --key-name ${key_name} --security-group-ids ${sg_id} --instance-type t2.micro --subnet-id ${subnet_id} --placement AvailabilityZone=${zone_aws} --output json --query 'Instances[0].InstanceId' | tr -d '"')
echo Instance ID: $instance_id
echo

echo Acrescentando portas 880, 443 e 22 na regra de inbound
aws ec2 authorize-security-group-ingress --group-id ${sg_id} --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id ${sg_id} --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id ${sg_id} --protocol tcp --port 443 --cidr 0.0.0.0/0
echo

echo Criando IP publico
eip_id=$(aws ec2 allocate-address --domain vpc --output json --query 'AllocationId' | tr -d '"')
echo Allocation ID: $eip_id
echo

echo Criando volume
volume_id=$(aws ec2 create-volume --size 10 --volume-type gp2 --availability-zone ${zone_aws} --output json --query 'VolumeId' | tr -d '"')
echo Volume ID: $volume_id
echo

while [ $(aws ec2 describe-instances --instance-ids $instance_id --output json --query 'Reservations[0].Instances[0].State.Name' | tr -d '"') != 'running' ]
do
   echo Esperando instância iniciar
   sleep 4
done

echo
echo Atachando volume à instância
aws ec2 attach-volume --volume-id ${volume_id} --instance-id $instance_id --device $device_to_volume
echo

echo Associando o IP público à instância criada
aws ec2 associate-address --instance-id ${instance_id} --allocation-id ${eip_id}
echo
