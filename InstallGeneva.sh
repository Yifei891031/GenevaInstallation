#!/bin/bash
log="/var/log/InstallGeneva.log"
BLOB_CONTAINER_URL=$1
BLOB_CONTAINER_SAS=$2

###################
echo "==== Bootstrapping ... ====" |& sudo tee $log
###################

echo "Download and install Docker"
sudo yes Y | apt-get install docker.io
sudo docker login linuxgeneva-microsoft.azurecr.io -u d22ddbdc-a4ce-4dae-b544-29560ed74814 -p 00d498a8-5a44-4ac5-bd2a-e1d0113aca11

echo "Download MDM Cert"
mkdir /home/sshuser
mkdir /home/sshuser/MA
mkdir /home/sshuser/MA/geneva_mdm
curl -o /home/sshuser/MA/geneva_mdm/mdm-cert.pem $BLOB_CONTAINER_URL/GenevaLinux/mdm-cert.pem$BLOB_CONTAINER_SAS
curl -o /home/sshuser/MA/geneva_mdm/mdm-key.pem $BLOB_CONTAINER_URL/GenevaLinux/mdm-key.pem$BLOB_CONTAINER_SAS

echo "Remove docker container"
echo "Remove docker container mdmdi"
sudo docker rm -f mdmdi
echo "Remove docker container mdmstatsddi"
sudo docker rm -f mdmstatsddi
echo "Remove docker container mdsddi"
sudo docker rm -f mdsddi
echo "Remove docker container fluentddi"
sudo docker rm -f fluentddi


echo "Run docker"
sudo docker run -d \
    -v /home/sshuser/MA/geneva_mdm:/tmp/geneva_mdm \
    -v /var/etw \
    --net=host \
    --uts=host \
    -e MDM_ACCOUNT="O365IpCore" \
    -e METRIC_ENDPOINT="https://global.metrics.nsatc.net/" \
    -e MDM_LOG_LEVEL="Warning" \
    --name=mdmdi \
    linuxgeneva-microsoft.azurecr.io/genevamdm:master_548

echo "Download mdmstat config"
mkdir /home/sshuser/MA/geneva_mdmstatsd
curl -o /home/sshuser/MA/geneva_mdmstatsd/mdmstatsd.conf $BLOB_CONTAINER_URL/GenevaLinux/mdmstatsd.conf$BLOB_CONTAINER_SAS
echo "Run docker"
sudo docker run -d \
    -v /home/sshuser/MA/geneva_mdmstatsd:/tmp/geneva_mdmstatsd \
    --volumes-from mdmdi \
    --net=host \
    --uts=host \
    --ipc="container:mdmdi" \
    --name=mdmstatsddi \
    linuxgeneva-microsoft.azurecr.io/genevamdmstatsd:master_548

echo "Download geneva mds"
mkdir /home/sshuser/MA/geneva_mdsd
curl -o /home/sshuser/MA/geneva_mdsd/gcscert.pem $BLOB_CONTAINER_URL/GenevaLinux/gcscert.pem$BLOB_CONTAINER_SAS
curl -o /home/sshuser/MA/geneva_mdsd/gcskey.pem $BLOB_CONTAINER_URL/GenevaLinux/gcskey.pem$BLOB_CONTAINER_SAS
curl -o /home/sshuser/MA/geneva_mdsd/mdsd.xml $BLOB_CONTAINER_URL/GenevaLinux/mdsd.xml$BLOB_CONTAINER_SAS
sudo docker run -d \
    -v /home/sshuser/MA/geneva_mdsd:/tmp/geneva_mdsd \
    -v /home/sshuser/MA/mdsd_run:/var/run/mdsd \
    -v /home/sshuser/MA/log:/var/log \
    --net=host \
    --uts=host \
    -e TENANT="O365IpDiTenant" \
    -e ROLE="O365IpDiRole" \
    -e ROLEINSTANCE="O365IpDiInstance" \
    -e MDSD_PORT=0 \
    -e MONITORING_GCS_ENVIRONMENT="DiagnosticsProd" \
    -e MONITORING_GCS_ACCOUNT="O365IpCore" \
    -e MONITORING_GCS_NAMESPACE="IpDataInsightsMdsd" \
    -e MONITORING_GCS_REGION="westus" \
    -e MONITORING_GCS_THUMBPRINT=D22080E526AB8D9FE11B534EBE204DE146C5687D \
    -e MDSD_OPTIONS="-c /tmp/geneva_mdsd/mdsd.xml" \
    --name=mdsddi \
    linuxgeneva-microsoft.azurecr.io/genevamdsd:master_912


echo "Download fluentd"
mkdir /home/sshuser/MA/fluentd
curl -o /home/sshuser/MA/fluentd/fluentd.conf  $BLOB_CONTAINER_URL/GenevaLinux/fluentd.conf$BLOB_CONTAINER_SAS
sudo docker run -d \
    -p 24224:24224 \
    -v /home/sshuser/MA/fluentd:/etc/fluentd \
    -v /home/sshuser/MA/mdsd_run:/var/run/mdsd \
    -e FLUENTD_CONF=/etc/fluentd/fluentd.conf \
    --name=fluentddi \
    linuxgeneva-microsoft.azurecr.io/genevafluentd_td-agent:master_78

