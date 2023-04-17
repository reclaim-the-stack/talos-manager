# Talos Manager

App built to help bootstrap and manage Talos Linux servers on Hetzner.

## Approach

Based on bootstrapping nodes via the `talos.config` kernel parameter (https://www.talos.dev/latest/reference/kernel/#talosconfig). This can be applied inside the Grub config of a Talos installation image. By writing the image to disk with `dd` and then mounting the boot partition we can inject the parameter into its `grub/grub.cfg`.

Example of passing a URL into the talos.config parameter:

```
talos.config=https://talos-manager.example.com/config?uuid=${uuid}
```

## Deploying

Feel free to deploy the application using our published container images at https://hub.docker.com/r/reclaimthestack/talos-manager/tags

Apart from deploying the application you'll also need to deploy a Postgres database and configure some ENV variables. Follow the SSH key and Heroku deployment instructions and apply the same ENV variables in whatever environment you're deploying on.

### Creating an SSH key and upload to Hetzner

Talos Manager will bootstrap servers by putting servers into Rescue Mode and then running commands on the servers via SSH. We need an SSH key configured for this.

Note: Due to Ruby's `net-ssh` library not being compatible with OpenSSL3 private keys we need to make sure we generate the private key in PEM format.

```
ssh-keygen -m PEM -t rsa -P "" -f ~/.ssh/talos-manager.pem -C talos-manager
```

Now add the public key (`cat ~/.ssh/talos-manager.pem.pub`) with the name `talos-manager` at:
- Hetzner Robot at https://robot.hetzner.com/key/index -> New key
- Hetzner Cloud at https://console.hetzner.cloud/ -> Select Project -> Security -> Add SSH Key

### Deploying on Heroku

First we'll create a Heroku application where we can deploy Talos Manager. For Postgres we'll use the `crunchy-postgres:hobby-1` costing $30/month. This plan provides continuous data protection and point in time recovery. If you plan to manually backup your postgres database you can also consider using `heroku-postgres:mini` at $5/month.

```
heroku create --stack container --region <eu/us> --addons crunchy-postgres:hobby-1 [--team <heroku-account>] <name-of-application>
```

Now clone the talos-manager repository and connect it to the heroku repository.

```
git clone https://github.com/reclaim-the-stack/talos-manager.git
cd talos-manager
heroku git:remote -a <name-of-application>
```

Now we can configure the application.

```
# We'll start by setting some standard Rails variables
heroku config:set \
  RAILS_ENV=production \
  SECRET_KEY_BASE=$(head /dev/urandom | md5) \
  AR_ENCRYPTION_PRIMARY_KEY=$(head /dev/urandom | md5) \
  AR_ENCRYPTION_DETERMINISTIC_KEY=$(head /dev/urandom | md5) \
  AR_ENCRYPTION_KEY_DERIVATION_SALT=$(head /dev/urandom | md5)

# Rails expects DATABASE_URL to connect to Postgres but crunchy uses CRUNCHY_DATABASE_URL
heroku config:set DATABASE_URL=$(heroku config:get CRUNCHY_DATABASE_URL)

# Manage Hetzner cloud API token at:
# https://console.hetzner.cloud -> Project -> Security -> API Tokens
# If you're not planning to use Hetzner cloud servers you can skip this part.
heroku config:set HETZNER_CLOUD_API_TOKEN=<hetzner-cloud-api-token>

# Manage Hetzner webservice API credentials at:
# https://robot.hetzner.com/preferences/index -> Webservice and app settings
# If you're not planning to use dedicated servers you can skip this part.
heroku config:set HETZNER_WEBSERVICE_USER=<username> HETZNER_WEBSERVICE_PASSWORD=<password>

# Note: You may want to change this to your own domain via the Heroku application settings page
heroku config:set HOST=<application-name>.herokuapp.com

# Assumes you created the SSH key for bootstrapping according to the instructions above
heroku config:set SSH_PRIVATE_KEY="$(cat ~/.ssh/talos-manager.pem)"

# Set a HTTP basic auth password to protect the app
heroku config:set BASIC_AUTH_PASSWORD=$(head /dev/urandom | md5)
```

Confirm that the Crunchy Postgres cluster is in ready status. This can take a few minutes after initial creation.

```
# If you can successfully psql to the database you're good to go
psql $(heroku config:get DATABASE_URL)

# If psql failed you can track the cluster status in the crunchy postgres dashboard
heroku addons:open crunchy-postgres
```

Once Postgres is ready, we're can go ahead and git push to build and deploy the application 🚀

```
git push heroku
```

Once the build has completed you should be able to access Talos Manager at `<name>.herokuapp.com` with the `BASIC_AUTH_PASSWORD` value as password.

## Solving invalid UUID issues

We have had some occasions where a newly rented dedicated server did not come with a properly configured SMBIOS UUID. If Talos Manager encounters a node with an invalid UUID it will raise an error during bootstrapping. To fix the issue: Login to Hetzner Robot UI. Navigate to support and get support for the server which is having issues. Send them an email in the style of:

```
Hi,

We have found that this server has an invalid SMBIOS UUID.

When running `dmidecode -t system` the output is:
<insert-output-of-dmidecode>

Note the pending fields + the UUID ending with 0'es.

We need to have a proper UUID since our disk encryption scheme is based on the entropy
of this UUID and with the one present here it doesn't work.

Downtime for the serving while solving this is fine, we won't be making use of the server until we get this solved.
```
