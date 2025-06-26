# example-lambda-s3-data



## setup

```bash
# access
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh --auth-key=tskey-auth-<AUTH-KEY>

# https://github.com/tailscale/tailscale/issues/7816#issuecomment-1499909112
mkdir -p /etc/systemd/resolved.conf.d
ln -sf /dev/null /etc/systemd/resolved.conf.d/resolved-disable-stub-listener.conf
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# packages
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y git go terraform

# repo
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token
vi ~/.gitconfig
[user]
        name = <NAME>
        email = <EMAIL>
[init]
        defaultBranch = main
[credential]
        helper = cache --timeout=3600

git clone https://github.com/simonhayward/example-lambda-s3-data.git

# auth
mkdir ~/.aws

vi ~/.aws/config
[default]
region = <REGION>
output = json

vi ~/.aws/credentials
[default]
aws_access_key_id = <ID>
aws_secret_access_key = <KEY>

chmod 0600 ~/.aws/*

# build
cd example-lambda-s3-data/tf/
vi backend.conf
bucket = "<BUCKET>"
key    = "<KEY>"
region = "<REGION>"

terraform init -backend-config=backend.conf

```
