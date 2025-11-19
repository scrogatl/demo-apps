Terraform "Outlier Detection" Demo Fleet
========================================

This directory contains all the configuration files needed to deploy a demo fleet of Amazon Linux 2 hosts instrumented with the latest New Relic infrastructure agent. The purpose is to build a group of 10 entities, with one creating a scheduled memory spike.

Project Structure
-----------------

```
.
├── main.tf                      # core terraform file
├── normal_load_user_data.sh     # normal load for the ASG nodes
├── outlier_load_user_data.sh    # outlier load for the bad actor
├── README.md                    # this file
├── terraform.tfvars.example     # example variables, copy this to terraform.tfvars
└── variables.tf                 # declares the vars for this terraform
```

Overview
--------

This Terraform project deploys a fleet of 10 EC2 instances designed to demo outlier detection monitoring. The fleet is composed of two parts (the "9+1" model), all tagged with `team: Demo Engineering` and `app: outlier_detection`.

1.  **The Fleet (9 Normal Nodes):**
    -   An Auto Scaling Group (ASG) maintains exactly 9 `t2.micro` instances.
    -   Each instance runs the `normal_load_user_data.sh` script on boot.
    -   This script installs the New Relic agent and then uses `stress-ng` to generate a continuous, varying load:
        -   **CPU:** 10-18%
        -   **Memory:** 33-42% (of 1GiB)

2.  **The Outlier (1 Anomaly Node):**
    -   A single, standalone `t2.medium` instance.
    -   It runs the `outlier_load_user_data.sh` script on boot, which does two things:
        1.  **Normal Load:** Installs the New Relic agent and runs the *exact same* continuous, varying load as the fleet.
        2.  **Periodic Spike:** Creates `memory-spike.service`. This service is configured to run **4 to 8 hours** after the *previous spike finished*. This creates a non-seasonal, random pattern.
            -   When triggered, it runs a script that immediately spikes memory to **90%** and holds it for a random duration (**7-12 minutes**).

This "9+1" setup guarantees that one of your 10 tagged instances will behave as an outlier at a different, unpredictable time, removing the challenge of seasonality with the alert algorithm.

Prerequisites
-------------
-   [Terraform CLI](https://developer.hashicorp.com/terraform/downloads "null") (v1.0.0+).
-   An AWS account.
-   Configured AWS credentials (e.g., via `aws configure` or environment variables).
-   A New Relic Account ID and User API Key.
-   An existing EC2 KeyPair for SSH access to the hosts.

How to Deploy
-------------

1.  **Initialize Terraform:**
    ```
    terraform init
    ```

2.  **Create and Configure Your Variables File:**
    Copy the example file to create your own local variables file (which is gitignored).

    ```
    cp terraform.tfvars.example terraform.tfvars
    ```

    Now, open the new `terraform.tfvars` file and:
    -   **New Relic:** Fill in the `new_relic_api_key` and `new_relic_account_id` with your New Relic credentials.
    -   **EC2 KeyPair:** Verify that `ec2_key_name` matches your existing keypair name for your target region.
    -   **IMPORTANT (Security):** Change `ssh_ingress_cidr` from `"0.0.0.0/0"` to your own IP address. You can find your IP by searching "what is my IP" and should format it as `"YOUR_IP/32"`.
    -   The `aws_region` where you'll build your EC2 instances.

3.  **Plan the Deployment:** (Optional) Review the resources that will be created.
    ```
    terraform plan
    ```

4.  **Apply the Configuration:** Terraform will ask for confirmation before building the infrastructure.
    ```
    terraform apply
    ```

    This will take a few minutes to provision the VPC, ASG, and instances.

How to Destroy
--------------

When you are finished with the demo, you can destroy all the resources to avoid ongoing costs.

```
terraform destroy
```

Validation
----------

* You can easily verify your results in New Relic using this NRQL, which should return `10`:

```
FROM SystemSample SELECT uniqueCount(entity.name)
WHERE team = 'Demo Engineering'
WHERE app = 'outlier_detection'
```

* Service logs for the bad actor

You can check your service logs on the outlier host with these 2 commands:

```
journalctl -u memory-spike.service -f
journalctl -u normal-load.service -f
```

* Manually testing the outlier

You can manually trigger a spike **at any time** on the outlier host by running:

```
sudo systemctl start memory-spike.service
```

**Tip:** This command will wait for the 7-12 minute spike to complete. To run it in the background and tail the logs immediately, use an ampersand (`&`):

```
sudo systemctl start memory-spike.service &
journalctl -u memory-spike.service -f
```
