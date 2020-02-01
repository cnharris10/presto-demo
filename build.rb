#!/usr/bin/ruby
valid_versions = ['323-e.4', '323-e.3', '323-e.2', '323-e.1']
puts 'Which version do you want to run? (323-e.4, 323-e.3, 323-e.2, 323-e.1)'
version = gets.chomp

default_version = '323-e.4'
if valid_versions.include?(version.to_s)
  puts "Deploy Presto version: #{version}"
  version
else
  puts "Invalid version given, deploying Presto version: #{default_version}"
  version = default_version
end

root = '/tmp/presto-demo'
build_dir = "#{root}/build"
dockerfile_dir = "#{build_dir}/docker-images-master/presto"

`mkdir -p #{build_dir}`
`cd #{build_dir}`

puts "Pulling presto Dockerfile"
puts `wget -P #{build_dir} https://github.com/starburstdata/docker-images/archive/master.zip #{build_dir}`
puts `unzip #{build_dir}/master.zip -d #{build_dir}`

# NOTE: I would make ALL deployments unique (i.e. add epoch seconds or similar)
# but building / uploading 2 GB images takes a long time
tag = "v#{version.gsub(/\./,'')}a"

region = ENV['AWS_REGION']
account_id = `aws2 sts get-caller-identity | jq -r '.Account'`.strip
repository = `aws2 ecr describe-repositories --region #{region}| jq -r '.repositories[].repositoryName'`.strip
ecr_host = "#{account_id}.dkr.ecr.#{region}.amazonaws.com"
image = "#{repository}:#{tag}"
ecr_host_and_image = "#{ecr_host}/#{image}"

puts "Building image: #{ecr_host_and_image}"
puts `docker build -t #{ecr_host_and_image} --build-arg presto_version=#{version} #{dockerfile_dir}`

puts "Acquiring docker login credentials"
docker_password = `aws2 ecr get-login-password --region #{region}`
puts `docker login -u AWS #{account_id}.dkr.ecr.#{region}.amazonaws.com -p #{docker_password}`

puts "Pushing image to ECR: #{ecr_host_and_image}"
puts `docker push #{ecr_host_and_image}`

puts "Set current context"
`kubectl config set-context arn:aws:eks:#{region}:#{account_id}:cluster/#{repository}`

puts "Get ecr token"
secret_name = 'ecr-secret-token'
token = `aws2 ecr --region=us-east-1 get-authorization-token --output text --query authorizationData[].authorizationToken | base64 -d | cut -d: -f2`

puts "Registering ECR token as Secret"
puts `kubectl delete secret #{secret_name}`
puts `kubectl create secret docker-registry #{secret_name} --docker-server="#{ecr_host}" --docker-username=AWS --docker-password="#{token}" --docker-email="cnharris@gmail.com"`

puts "Deploying presto #{tag}"
puts `helm upgrade presto /tmp/presto-demo/presto-chart --set aws.ecr.identifier=#{tag} --install`

puts "Deleting local artifacts: #{root}"
`rm -rf #{root}`
