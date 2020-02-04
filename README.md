# Presto running on EKS

![Presto Server running TPC-H queries](https://i.imgur.com/6AH0Bdv.jpg)

## Public URL
`http://a4198d97a45f011ea90cc162ea19c1da-be53022f08b9b5dc.elb.us-east-1.amazonaws.com`

## Running build script
```
git clone git@github.com:cnharris10/presto-demo.git /tmp/presto-demo && ruby /tmp/presto-demo/build.rb
```

## Architecture

- EKS Cluster
	- 2 subsets (us-east-1a, us-east-1f)
	- Security Group (80/443 exposed)
- NLB
	- 1 k8s Load Balancer Service
- 2 t3.large nodes
	- 2 k8s presto server pods


## Files / Components

- presto-chart (only calling out editted files)
	- templates
		- Deployment: `{{.Values.aws.ecr.identifier}}` --> Dynamic image identifer passed at build time.
		- Service
	- values
		- Shared data across multiple templates
- build.rb
	- Set presto-server version supplied by user
	- Options are `(323-e.4, 323-e.3, 323-e.2, 323-e.1)`
	- Create directory under tmp for all files
	- Download correct presto image and unzip contents
	- Docker
		- Build Presto image
		- Login
		- Push image to ECR via templated host and custom image name
	- Set correct Kuberentes context for deployments
	- Upsert ECR Secret
		- Allows Kubernetes to pull uploaded image
	- Helm: Apply deployment with new image identifier
	- Clean up local files


## Resources
- GCP vs. AWS: Where should you be running Kubernetes?: https://medium.com/@fairwinds/gcp-vs-aws-where-should-you-be-running-kubernetes-8f58e882b31c
- EKS: https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html
- ECR: https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_on_EKS.html
- Helm Docs: https://helm.sh/docs/
- Starburst Docs: https://docs.starburstdata.com/latest/docker.html
- ELB & SSL: https://github.com/vaquarkhan/vaquarkhan/wiki/Configure-AWS-ELB-classic-load-balancer-SSL-and-point-to--godaddy-domain
	- Attempted to try to run *.amazonaws.com ELB on SSL (not possible)
- Ingress vs. ELB: https://itnext.io/kubernetes-ingress-controllers-how-to-choose-the-right-one-part-1-41d3554978d2
- Kubernetes Cheatsheet: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- EKS with Terraform: https://aws.amazon.com/blogs/startups/from-zero-to-eks-with-terraform-and-helm/


## Time Spent

- Planning (~1 hour)
	- EKS vs. GKE
	- Mastering Jenkins not the right move for this project :)
- AWS (new account)
	- EKS Cluster (~30 min)
	- ECR support (~30 min)
- build.rb script (~3 hours)
- Helm Support (~1 hour)
- ELB Integration (~1 hour)
- README (~30 min)

**Total: ~7.5 hours**


## Optimization - Random Thoughts
- Security
	- MFA / Identity provider to alleviate static access / secret keys
	- Secure cluster with domain / matching SSL cert
		- Dedicated CNAME for ELB
	- Front-end proxy gateway (Secure access to Presto behind VPN)
	- Dedicated namespaces for N CI/CD environments
		- Locked-down user pool with RBAC
	- Truly unique tags
		- (Did not include for this demo because building images each time takes a while)
- Service Mesh: Istio
	- Blue/Green, Canary, multi-environment deploys
	- SSL network communication within cluster
	- Retryable requests
- Scalability
	- 1 replica for coordinator (I don't think Presto is multi-master at this point.)
	- Persistent volume(s) for log management?
	- HPA auto-scaling for workers
	- CDN for Presto UI elements
- Operations / Monitoring
	- ECR cron job for updating 12 hour key every N hours
	- Audit logs (ex: Cloudtrail, Stackdriver)
	- Log rotation / solution (3rd party, ELK, etc.)
	- Metrics store solution (i.e. Prometheus)
	- Multi-environment CI/CD solution
- Infrastructure-as-Code
	- Build all AWS assets in Terraform or similar
	- Assets include:
		- User
		- Roles
		- Groups
		- EKS
			- VPC
			- IAM Roles/Policies
			- Security Groups
			- Internet Gateway
			- Subnets
			- ASG
			- Routing
			- Kubectl Integration


## Installed Libraries
(Presupposing Mac environment)
- rvm: `https://rvm.io/`
  	- ruby 2.7: `rvm install 2.7.0`
- homebrew: `https://brew.sh/`
	- jq: `brew install jq`
	- kubectl (v1.17.2): `brew install kubectl`
	- helm (3.0.3): `brew install helm`
- docker: `https://docs.docker.com/install/`
- aws2: `https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux-mac.html#cliv2-linux-mac-install`
- eksctl: `https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html`
- helm: `https://helm.sh/docs/intro/install/`


## Running Presto Client within Container
```
kubectl exec -it $(kubectl get pods | awk 'NR==2 { print $1 }') -- ./presto-cli --catalog tpch --schema tiny
presto:tiny> select count(*) from lineitem;
 _col0
-------
 60175
(1 row)

Query 20200202_132008_00001_gqfua, FINISHED, 1 node
Splits: 21 total, 21 done (100.00%)
0:07 [60.2K rows, 0B] [8.64K rows/s, 0B/s]
```
