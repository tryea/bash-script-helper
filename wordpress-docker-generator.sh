#!/bin/bash

# Check if openssl is installed
if ! command -v openssl &> /dev/null
then
    echo "openssl could not be found"
    echo "It's recommended to install openssl for generating secure passwords."
    echo "Would you like to install openssl now? [Y/n]"
    read response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
    then
        sudo apt-get update
        sudo apt-get install openssl -y
    else
        echo "Skipping openssl installation. Please install openssl manually if you need to generate secure passwords."
        exit 1
    fi
fi

# Check number of arguments
if [ $# -ne 3 ]; then
  echo "Usage: $0 [project name] [wordpress port] [mysql port]"
  exit 1
fi

# Get project name and port from arguments
PROJECT_NAME=$1
WP_PORT=$2
DB_PORT=$3

# Function to check if a port is in use
is_port_in_use() {
  netstat -tuln | grep -q ":$1 "
  return $?
}

# Check if wordpress port is in use
if is_port_in_use $WP_PORT; then
  echo "Error: WordPress port $WP_PORT is already in use."
  exit 1
fi

# Check if database port is in use
if is_port_in_use $DB_PORT; then
  echo "Error: Database port $DB_PORT is already in use."
  exit 1
fi

# Check if wordpress port and database port are the same
if [ $WP_PORT -eq $DB_PORT ]; then
  echo "Error: WordPress port and Database port cannot be the same."
  exit 1
fi

# Check if wordpress port is a number between 1024 and 49151
if [[ ! $WP_PORT =~ ^[0-9]+$ ]] || [ $WP_PORT -lt 1024 ] || [ $WP_PORT -gt 49151 ]; then
  echo "Error: Invalid wordpress port number. Please enter a number between 1024 and 49151."
  exit 1
fi

# Check if database port is a number between 1024 and 49151
if [[ ! $DB_PORT =~ ^[0-9]+$ ]] || [ $DB_PORT -lt 1024 ] || [ $DB_PORT -gt 49151 ]; then
  echo "Error: Invalid wordpress port number. Please enter a number between 1024 and 49151."
  exit 1
fi

# Generate a random username
if [[ $(uname) == "Darwin" ]]; then
    # MacOS
    DB_USERNAME=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 10)
else
    # Linux
    DB_USERNAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
fi

# Generate a random password
if command -v pwgen &> /dev/null
then
    ROOT_PASSWORD=$(pwgen 32 1 -B -s -v)
    DB_PASSWORD=$(pwgen 32 1 -B -s -v)
else
    echo "pwgen could not be found"
    echo "It's recommended to install pwgen for generating secure passwords."
    echo "Would you like to install pwgen now? [Y/n]"
    read response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
    then
        sudo apt-get update
        sudo apt-get install pwgen -y
        ROOT_PASSWORD=$(pwgen 32 1 -B -s -v)
        DB_PASSWORD=$(pwgen 32 1 -B -s -v)
    else
        echo "Skipping pwgen installation. Please install pwgen manually if you need to generate secure passwords."
        exit 1
    fi
fi

# Convert to lowercase and replace spaces with dashes
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

# Create a new directory for the project
mkdir $PROJECT_NAME

# Go into the project directory
cd $PROJECT_NAME

# Create the docker-compose.yml file
cat << EOF > $PROJECT_NAME-docker-compose.yml
version: '3.1'

services:
  db:
    image: mysql:5.7
    volumes:
      - db_data:/var/lib/mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $ROOT_PASSWORD
      MYSQL_DATABASE: wordpress
      MYSQL_USER: $DB_USERNAME
      MYSQL_PASSWORD: $DB_PASSWORD

  wordpress:
    depends_on:
      - db
    build: .
    ports:
      - $WP_PORT:$WP_PORT
    restart: always
    environment:
      WORDPRESS_DB_HOST: db:$DB_PORT
      WORDPRESS_DB_USER: $DB_USERNAME
      WORDPRESS_DB_PASSWORD: $DB_PASSWORD
      WORDPRESS_DB_NAME: wordpress
volumes:
    db_data: {}
EOF

#create new directory for uploads.ini
mkdir php-conf
# Create the docker-compose.yml file
cat << EOF > Dockerfile
FROM wordpress:latest

# Copy configuration file
COPY php-conf/uploads.ini /usr/local/etc/php/conf.d/uploads.ini

EOF

cat << EOF > php-conf/uploads.ini
file_uploads = On
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
EOF

# Create the deploy.sh file
cat << EOF > deploy.sh
#!/bin/bash

# Check number of arguments
if [ \$# -ne 2 ]; then
  echo "Usage: \$0 [domain] [email]"
  exit 1
fi

# Get project name, domain, and email from arguments
DOMAIN=\$1
EMAIL=\$2


# Start the docker containers
docker compose -f $PROJECT_NAME-docker-compose.yml up -d

# Wait for the containers to start
sleep 10

# Create the Nginx config file
cat << EOF2 > /etc/nginx/sites-available/\$DOMAIN
server {
    listen 80;
    server_name \$DOMAIN;

    location / {
        proxy_pass http://localhost:$WP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF2

# Enable the Nginx config
ln -s /etc/nginx/sites-available/\$DOMAIN /etc/nginx/sites-enabled/

# Reload Nginx
service nginx reload

# Obtain and install the SSL certificate
certbot --nginx -d \$DOMAIN --non-interactive --agree-tos --hsts -m \$EMAIL --redirect

# Reload Nginx
service nginx reload
EOF

# Make the deploy.sh script executable
chmod +x deploy.sh

# Print instructions
echo "Docker Compose file created for project: $PROJECT_NAME"
echo "To start your WordPress instance, run the following commands:"
echo "cd $PROJECT_NAME"
echo "docker compose -f $PROJECT_NAME-docker-compose.yml up -d"
echo "DB Connection details:"
echo "Database host: localhost (if MySQL client is installed on the host)"
echo "Database port: $DB_PORT (if MySQL client is installed on the host)"
echo "Database name: wordpress"
echo "Username: $DB_USERNAME"
echo "Password: $DB_PASSWORD"
echo "Note: If the MySQL client is not installed on the host, you can use 'docker exec -it [CONTAINER_ID] bash' to access the container's bash shell and run 'mysql -u [USERNAME] -p' to connect to the database."
echo "mysql://${DB_USERNAME}:${DB_PASSWORD}@IP_ADDRESS:${DB_PORT}/wordpress"

