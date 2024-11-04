#!/bin/bash

# Set variables
MARIADB_POD="mariadb-0"                    # MariaDB pod name
NAMESPACE=""                         # Kubernetes namespace

SQL_USER="-app"                         # Database username
SQL_PASSWORD=""                    # Database password
DATABASE_NAME=""                  # Database name
DUMP_FILE=".sql"       # SQL dump filename

BUCKET_NAME="drupal-bucket"            # Google Cloud Storage bucket name

PORTAL_POD="-0"                   # Portal pod name
PROJECT_ID=""                    # Google Cloud project ID

VM_NAME=""                   # VM name for the portal
ZONE="us-central1-a"                       # Zone for the VM instance


# Export MariaDB Database to a SQL file
kubectl exec -it $MARIADB_POD -n $NAMESPACE -- mysqldump -u $SQL_USER -p$SQL_PASSWORD --databases $DATABASE_NAME --skip-triggers --skip-add-drop-table --default-character-set=utf8mb4 > $DUMP_FILE

# Modify the database name in the dump file
sed -i 's/`devportal`/``/g' $DUMP_FILE

# Upload the SQL dump to Google Cloud Storage
gcloud storage cp $DUMP_FILE gs://$BUCKET_NAME/$DUMP_FILE --project=$PROJECT_ID

# Compress portal files in the pod and copy to local
kubectl exec -it $PORTAL_POD -n $NAMESPACE -- tar -zcvf /var/www/portal.tar.gz -C /var/www portal
kubectl cp $PORTAL_POD:/var/www/portal.tar.gz ./portal.tar.gz -n $NAMESPACE

# Transfer compressed files to VM instance via IAP
gcloud compute scp --recurse ./portal.tar.gz $VM_NAME:/home/ --zone=$ZONE --project=$PROJECT_ID --tunnel-through-iap

# SSH into the VM to configure environment
gcloud compute ssh $VM_NAME --zone=$ZONE --project=$PROJECT_ID --tunnel-through-iap --command="
    # Update and install required packages
    sudo apt update
    sudo apt install -y software-properties-common
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt install -y apache2 php8.2 php8.2-cli php8.2-fpm php8.2-mbstring php8.2-xml php8.2-curl php8.2-zip php8.2-mysql php8.2-gd default-mysql-client

    # Extract portal files to web directory
    tar -xzvf /home/portal.tar.gz
    sudo mv ./portal/ /var/www/
    sudo chown -R www-data:www-data /var/www/portal
    sudo chmod -R 755 /var/www/portal

    # Configure Apache for Drupal
    sudo sed -i '/DocumentRoot .*/d' /etc/apache2/sites-available/000-default.conf && \
    sudo sed -i '/<VirtualHost \*:80>/a \
    DocumentRoot /var/www/portal/web\n\
    <Directory /var/www/portal/web>\n\
      AllowOverride All\n\
      Require all granted\n\
    </Directory>' /etc/apache2/sites-available/000-default.conf

    # Enable rewrite module and restart Apache
    sudo a2enmod rewrite
    sudo systemctl restart apache2

    # Increase PHP memory limit and enable LDAP extension
    echo 'memory_limit = -1;extension=ldap;' > /usr/local/etc/php/php.ini 
"

# Configure Drupal to connect to Cloud SQL (Edit settings.php with required DB details)
gcloud compute ssh $VM_NAME --zone=$ZONE --project=$PROJECT_ID --tunnel-through-iap --command="
    cat <<EOF >> /var/www/portal/web/sites/default/settings.php
    \$databases['default']['default'] = [
      'driver' => 'mysql',
      'database' => 'nwc_dev_db',
      'username' => 'nwc-app',
      'password' => 'NWC?2025',
      'host' => '10.63.48.3',
      'port' => '3306',
      'prefix' => '',
    ];
    EOF
"

# Github Actions Pipeline for deployment to the VM
gcloud compute scp --recurse ./Source/portal ${{ env.VM_NAME }}:/home/runner/ --zone=${{ env.ZONE }} --project=${{ env.PROJECT_ID }} --tunnel-through-iap

gcloud compute ssh ${{ env.VM_NAME }} --zone=${{ env.ZONE }} --project=${{ env.PROJECT_ID }} --tunnel-through-iap --command="
    # Add database configuration to settings.php
    echo '\$databases[\"default\"][\"default\"] = [' >> /home/runner/portal/web/sites/default/settings.php && \
    echo '  \"driver\" => \"mysql\",' >> /home/runner/portal/web/sites/default/settings.php && \
    echo '  \"database\" => \"nwc_dev_db\",' >> /home/runner/portal/web/sites/default/settings.php && \
    echo '  \"username\" => \"nwc-app\",' >> /home/runner/portal/web/sites/default/settings.php && \
    echo '  \"password\" => \"NWC?2025\",' >> /home/runner/portal/web/sites/default/settings.php && \
    echo '  \"host\" => \"10.63.48.3\",' >> /home/runner/portal/web/sites/default/settings.php && \
    echo '  \"port\" => \"3306\",' >> /home/runner/portal/web/sites/default/settings.php && \
    echo '  \"prefix\" => \"\",' >> /home/runner/portal/web/sites/default/settings.php && \
    echo '];' >> /home/runner/portal/web/sites/default/settings.php

    # Deploy files to web directory and clean up
    sudo rsync -a /home/runner/portal/* /var/www/portal/
    sudo rm -rf /home/runner/portal/
"
