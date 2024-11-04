# Drupal Portal Migration and Deployment

This repository contains scripts and configurations for migrating and deploying a Drupal portal with a MariaDB database hosted in Kubernetes, using Google Cloud Platform (GCP) resources. The solution includes exporting the database, configuring Drupal settings, transferring files, and setting up the environment on a Compute Engine VM. 

## Prerequisites

- **GCP Project** with permissions for Compute Engine, Kubernetes, Cloud Storage, and Cloud SQL.
- **GCP SDK** installed and authenticated.
- **Kubernetes Cluster** with a MariaDB pod.
- **GitHub Actions** configured for CI/CD (optional).

## Environment Variables

These variables should be configured in your script or GitHub Actions for seamless execution:

- `PROJECT_ID` - Google Cloud project ID
- `ZONE` - GCP zone where the Compute Engine VM is located
- `VM_NAME` - Name of the Compute Engine VM for deployment
- `NAMESPACE` - Kubernetes namespace where the pods are running
- `MARIADB_POD` - MariaDB pod name in Kubernetes
- `SQL_USER` - MariaDB database username
- `SQL_PASSWORD` - MariaDB database password
- `DATABASE_NAME` - Database name to be exported
- `DUMP_FILE` - Filename for SQL dump
- `BUCKET_NAME` - Google Cloud Storage bucket name for storing backups
- `PORTAL_POD` - Portal pod name in Kubernetes

## Script Overview

1. **Database Export**: Exports the MariaDB database from a Kubernetes pod to a SQL dump file, changes the database name within the dump, and uploads it to a Google Cloud Storage bucket.
2. **File Transfer**: Compresses the portal files in the Kubernetes pod, copies them locally, and transfers them to a Compute Engine VM.
3. **VM Setup**: Installs necessary packages, configures Apache and PHP, and moves the portal files to the appropriate web directory on the VM.
4. **Drupal Database Configuration**: Sets up the Drupal database configuration in `settings.php` to connect to Cloud SQL.
5. **GitHub Actions Deployment**: Pipeline commands for automated deployment, database configuration, and file syncing on the VM.

## Usage

1. **Run the Script Locally**:
   To execute the deployment script locally, set the environment variables or replace them directly in the script.

   ```bash
   chmod +x gke-gce.sh
   ./gke-gce.sh
