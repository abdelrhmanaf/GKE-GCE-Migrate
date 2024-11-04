# Set project and network variables
PROJECT_ID=                    # Project ID for Google Cloud project
VPC_NAME=                      # Name for the VPC
SUBNET_NAME=                   # Name for the subnet
CIDR_RANGE=                    # IP range for the subnet
REGION=                        # Region for the resources
INSTANCE_GROUP_NAME=           # Instance group name
INSTANCE_GROUP_ZONE=           # Zone for the instance group

# Enable Compute Engine API
gcloud services enable compute.googleapis.com

# Create a VPC network with custom subnet mode
gcloud compute networks create $VPC_NAME \
--project=$PROJECT_ID \
--subnet-mode=custom \
--mtu=1460 \
--bgp-routing-mode=regional 

# Create a subnet within the VPC
gcloud compute networks subnets create $SUBNET_NAME \
--project=$PROJECT_ID \
--range=$CIDR_RANGE \
--stack-type=IPV4_ONLY \
--network=$VPC_NAME \
--region=$REGION \
--enable-private-ip-google-access

# Enable Service Networking API for private IP access
gcloud services enable servicenetworking.googleapis.com

# Create a firewall rule to allow SSH from IAP (Identity-Aware Proxy) IP ranges
gcloud compute firewall-rules create allow-ingress-from-iap \
  --direction=INGRESS \
  --action=allow \
  --rules=tcp:22 \
  --network=$VPC_NAME \
  --source-ranges=35.235.240.0/20

# Create firewall rule to allow health checks on TCP port 80
gcloud compute --project=$PROJECT_ID firewall-rules create fw-allow-health-checks \
    --direction=INGRESS \
    --priority=1000 \
    --network=$VPC_NAME \
    --action=ALLOW \
    --rules=tcp:80 \
    --source-ranges=35.191.0.0/16,130.211.0.0/22

# Create a Compute Engine VM instance
gcloud compute instances create $VM_NAME --project=$PROJECT_ID \
    --zone=$INSTANCE_GROUP_ZONE \
    --machine-type=e2-standard-2 \
    --network-interface=stack-type=IPV4_ONLY,subnet=$SUBNET_NAME,no-address \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=sa@$PROJECT_ID.iam.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_write,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/sqlservice.admin,https://www.googleapis.com/auth/trace.append \
    --create-disk=auto-delete=yes,boot=yes,device-name=$VM_NAME,image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20241016,mode=rw,size=50,type=pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any

# Create an unmanaged instance group
gcloud compute instance-groups unmanaged create $INSTANCE_GROUP_NAME \
    --project=$PROJECT_ID \
    --zone=$INSTANCE_GROUP_ZONE

# Set named ports for the unmanaged instance group
gcloud compute instance-groups unmanaged set-named-ports $INSTANCE_GROUP_NAME \
    --project=$PROJECT_ID \
    --zone=$INSTANCE_GROUP_ZONE \
    --named-ports=http:80

# Add instances to the unmanaged instance group (Add your VM instance name in place of "<INSTANCE_NAME>")
gcloud compute instance-groups unmanaged add-instances $INSTANCE_GROUP_NAME \
    --project=$PROJECT_ID \
    --zone=$INSTANCE_GROUP_ZONE \
    --instances=<INSTANCE_NAME>
