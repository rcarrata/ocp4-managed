# ROSA Install

## Prerequisites for AWS CLI

* Export the AWS credentials of your AWS account:

```sh
export AWSKEY="xxxx"
export AWSSECRETKEY="yyyy"
export REGION=eu-west-1
```

* Download and configure the AWS CLI with the credentials and check the credentials with the sts get-caller-identity command:

```sh
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
./awscli-bundle/install -i /usr/local/aws -b /bin/aws
/bin/aws --version
mkdir $HOME/.aws

cat << EOF > $HOME/.aws/credentials
[default]
aws_access_key_id = ${AWSKEY}
aws_secret_access_key = ${AWSSECRETKEY}
region = $REGION
EOF

aws sts get-caller-identity
```

## Get ROSA CLI

* Set up the ROSA CLI:

```sh
cd /tmp
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/rosa/latest/rosa-linux.tar.gz
tar xfvz rosa-linux.tar.gz -C /tmp
chmod u+x rosa
rosa completion > /tmp/rosa
sudo mv /tmp/rosa /etc/bash_completion.d/rosa
```

* Get a Red Hat Offline Access Token:

```sh
export token="xxxx"
```

* Login with the ROSA cli using the token obtained:

```sh
rosa login --token=$token

I: Logged in as 'xxx@redhat.com' on 'https://api.openshift.com'
```

* Verify that ROSA has the minimal permissions:

```sh
rosa verify permissions
I: Validating SCP policies...
I: AWS SCP policies ok
```

* Check ROSA account:

```sh
rosa whoami

AWS Account ID:               xxx
AWS Default Region:           eu-west-1
AWS ARN:                      arn:aws:iam::xxx:user/xxx@redhat.com-2151
OCM API:                      https://api.openshift.com
OCM Account ID:               xxx
OCM Account Name:             RCS RCS
OCM Account Username:         rhn-xxx-xxx
OCM Account Email:            xxx@redhat.com
OCM Organization ID:          xxx
OCM Organization Name:        RCS RCS
OCM Organization External ID: xxx
```

* Export the ROSA specifics for the cluster:

```sh
export ROSA_CLUSTER="rosa-rcarrata"
export ROSA_REGION="eu-west"
export ROSA_MACHINE_CIDR="10.0.0.0/16"
export ROSA_SERVICE_CIDR="172.30.0.0/16"
export ROSA_POD_CIDR="10.128.0.0/14"
export ROSA_COMPUTE_NODES="2"
```

* Initialize the ROSA CLI to complete the remaining validation checks and configurations:

```sh
rosa init --region  $REGION
```

* Create ROSA cluster with the following parameters:

```sh
rosa create cluster --cluster-name $ROSA_CLUSTER --region $ROSA_REGION --compute-nodes $ROSA_COMPUTE_NODES --machine-cidr $ROSA_MACHINE_CIDR --service-cidr $ROSA_SERVICE_CIDR --pod-cidr $ROSA_POD_CIDR --watch
```

* After 40 minutes approx the ROSA cluster it's ready:

```sh
rosa list cluster
ID                                NAME           STATE
xxxxxxxxxxxxxxxxxxxxxxxxxxx  rosa-rcarrata  ready
```

### Creating admin users

By default, only the OpenShift SRE team will have access to the ROSA cluster. To add a local admin user, run the following command to create the cluster-admin account in your cluster.

* Create a cluster-admin user (htpassw idp) in the ROSA cluster:

```sh
rosa create admin --cluster=<cluster_name>
```

* Copy the login command returned to you in the previous step and paste that into your terminal. This should log you into the cluster via the CLI so you can start using the cluster.

```sh
rosa describe cluster --cluster $ROSA_CLUSTER

API_ROSA_CLUSTER=$(rosa describe cluster --cluster $ROSA_CLUSTER -o json | jq -r .api.url)

PASSWORD="xxx"

oc login $API_ROSA_CLUSTER --username cluster-admin --password xxx
```

* Get the web console link to the ROSA cluster:

```sh
CONSOLE_CLUSTER=$(CONSOLE=$(rosa describe cluster --cluster $ROSA_CLUSTER -o json | jq -r .console.url))
```

## Make Cluster Private

```sh
rosa edit ingress --private=true --cluster=rosa-rcarrata apps
I: Updated ingress 'x3k6' on cluster 'rosa-rcarrata'
```

```sh
kubectl get publishingstrategies -n openshift-cloud-ingress-operator publishingstrategy -o jsonpath='{.spec}' | jq -r .
{
  "applicationIngress": [
    {
      "certificate": {
        "name": "rosa-rcarrata-primary-cert-bundle-secret",
        "namespace": "openshift-ingress"
      },
      "default": true,
      "dnsName": "apps.rosa-rcarrata.apea.p1.openshiftapps.com",
      "listening": "internal",
      "routeSelector": {}
    }
  ],
  "defaultAPIServerIngress": {
    "listening": "external"
  }
}
```

```sh
kubectl get publishingstrategies -n openshift-cloud-ingress-operator publishingstrategy -o jsonpath='{.spec.applicationIngress[0].listening}'

internal
```

### Create aditional ingresses (for apps)

```sh
rosa create ingress --cluster rosa-rcarrata apps2

I: Ingress has been created on cluster 'rosa-rcarrata'.
I: To view all ingresses, run 'rosa list ingresses -c rosa-rcarrata'
```

```sh
kubectl get pod -n openshift-ingress
NAME                              READY   STATUS    RESTARTS   AGE
router-apps2-6fdbfb685d-5rgz7     1/1     Running   0          3m23s
router-apps2-6fdbfb685d-jj5hn     1/1     Running   0          3m23s
router-default-685f97cd9c-4wp2b   1/1     Running   0          24m
router-default-685f97cd9c-k5ldx   1/1     Running   0          24m
```

```sh
kubectl get ingresscontroller -n openshift-ingress-operator apps2 -o jsonpath='{.spec}' | jq -r .
{
  "clientTLS": {
    "clientCA": {
      "name": ""
    },
    "clientCertificatePolicy": ""
  },
  "defaultCertificate": {
    "name": "rosa-rcarrata-primary-cert-bundle-secret"
  },
  "domain": "apps2.rosa-rcarrata.xxx.p1.openshiftapps.com",
  "endpointPublishingStrategy": {
    "loadBalancer": {
      "scope": "External"
    },
    "type": "LoadBalancerService"
  },
  "httpEmptyRequestsPolicy": "Respond",
  "httpErrorCodePages": {
    "name": ""
  },
  "nodePlacement": {
    "nodeSelector": {
      "matchLabels": {
        "node-role.kubernetes.io/infra": ""
      }
    },
    "tolerations": [
      {
        "effect": "NoSchedule",
        "key": "node-role.kubernetes.io/infra",
        "operator": "Exists"
      }
    ]
  },
  "routeSelector": {},
  "tuningOptions": {},
  "unsupportedConfigOverrides": null
}
```

```
rosa create ingress --cluster rosa-rcarrata apps3
E: Failed to add ingress to cluster 'rosa-rcarrata': Ingresses are currently limited to no more than 2
```