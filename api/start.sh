#!/bin/bash

### Set Defaults
    export ADMIN_EMAIL=${ADMIN_EMAIL:-"admin@example.com"}
    export ADMIN_PASS=${ADMIN_PASS:-"password"}
    API_URL=${VIRTUAL_HOST:-"127.0.0.1"}
    APP_URL=${VIRTUAL_HOST:-"127.0.0.1"}
    DB_PORT=${DB_PORT:-"27017"}
    DB_SECRET=${DB_SECRET:-"secret"}
    DB_HOST=${DB_HOST:-"127.0.0.1"}
    DB_NAME=${DB_NAME:-"formio"}
    JWT_SECRET=${JWT_SECRET:-"secret"}
    JWT_EXPIRETIME=${JWT_EXPIRETIME:-"240"}
    MAIL_TYPE=${MAIL_TYPE:-"sendgrid"}
    MYSQL_PORT=${MYSQL_PORT:-"3306"}
    MSSQL_PORT=${MYSQL_PORT:-"1433"}
    REVERSE_PROXY=${REVERSE_PROXY:-"false"}

    if [ "$REVERSE_PROXY" = "true" ] || [ "$REVERSE_PROXY" = "TRUE" ];  then
        URL_PREFIX=https://
    else
        URL_PREFIX=http://
    fi

### Sanity Check
    if [ -z ${DB_HOST} ] ; then printf "\n\nDB_HOST is not defined!\n"; exit 1; fi;
    if [ -z ${DB_NAME} ] ; then printf "\n\nDB_NAME is not defined!\n"; exit 1; fi;
# todo more sanity checks (port,secret etc)

### Check if installed
    chown -R nodejs:nodejs /app 
    if [ ! -f "/app/index.js" ]; then
        echo '** [formio] No Data Found, Creating Fresh Install'
        apt-get update
        apt-get install -y \
            git \
            g++ \
            make
        sudo -u nodejs git clone https://github.com/formio/formio /app
        cd /app
        sudo -u nodejs npm install

        apt-get purge -y \
                git \
                g++ \
                make
        apt-get -y autoremove 
        apt-get clean 
        rm -rf /var/lib/apt/lists/*
        touch /app/needs-install
    fi

  # Set DB Parameters
    jsontmp=$(mktemp)
    jq '.mongo="mongodb://'$DB_HOST':'$DB_PORT'/'$DB_NAME'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
    jq '.mongoSecret="'$MONGO_SECRET'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
    jq '.jwt .secret="'$JWT_SECRET'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
    jq '.jwt .expireTime="'$JWT_EXPIRETIME'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json

    jq '.email .type="'$MAIL_TYPE'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
    jq '.email .username="'$MAIL_USER'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
    jq '.email .password="'$MAIL_PASS'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json

    if [ ! -z ${MYSQL_HOST}] ; then
	    jq '.settings .database .mysql .host="'$MYSQL_HOST'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
	    jq '.settings .database .mysql .port="'$MYSQL_PORT'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json 
	    jq '.settings .database .mysql .database="'$MYSQL_DB_NAME'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
	    jq '.settings .database .mysql .user="'$MYSQL_DB_USER'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
	    jq '.settings .database .mysql .password="'$MYSQL_DB_PASS'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
    fi

    if [ ! -z ${MSSQL_HOST}] ; then
	    jq '.settings .database .mssql .host="$'MSSQL_HOST'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
	    jq '.settings .database .mssql .port="$'MSSQL_PORT'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json 
	    jq '.settings .database .mssql .database="'$MSSQL_DB_NAME'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
	    jq '.settings .database .mssql .user="'$MSSQL_DB_USER'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
	    jq '.settings .database .mssql .password="'$MSSQL_DB_PASS'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
    fi

    if [ ! -z ${MAIL_SENDGRID_API_USER}] ; then
    	jq '.settings .email .sendgrid .auth .api_user="'$MAIL_SENDGRID_API_USER'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
    	jq '.settings .email .sendgrid .auth .api_key="'$MAIL_SENDGRID_API_KEY'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
    fi

    if [ ! -z ${MAIL_GMAIL_USER}] ; then
	    jq '.settings .email .gmail .auth .user="'$MAIL_GMAIL_USER'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
	    jq '.settings .email .gmail .auth .pass="'$MAIL_GMAIL_PASS'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
	fi

    if [ ! -z ${MAIL_MANDRILL_API_KEY}] ; then
	    jq '.settings .email .mandrill .auth .apiKey="'$MAIL_MANDRILL_API_KEY'"' /app/config/default.json > "$jsontmp" && mv "$jsontmp" /app/config/default.json
    fi

    if [ -f "/app/needs-install" ]; then
        cat <<EOF > /tmp/install.sh
#!/usr/bin/expect

cd /app
spawn /usr/bin/node /app/main.js
expect "(y/N)"
send -- "y\n"
expect "(1)"
send -- "https://github.com/formio/formio-app-formbuilder\n"
expect "(client)"
send -- "\n"
expect "account"
send -- "${ADMIN_EMAIL}\n"
expect "account"
send -- "${ADMIN_PASS}\n"
expect "Install successful!"
send -- "\003"
exit 0
EOF
        chmod +x /tmp/install.sh
        sudo -u nodejs expect /tmp/install.sh
        rm -rf /tmp/install.sh
        rm -rf /app/needs-install
    fi

### Change URLs
sed -i "/var APP_URL = /c\var APP_URL = '$URL_PREFIX$APP_URL';" /app/client/dist/config.js
sed -i "/var API_URL = /c\var API_URL = '$URL_PREFIX$API_URL';" /app/client/dist/config.js
# for formbuilder
sed -i "/var APP_URL = /c\var APP_URL = '$URL_PREFIX$APP_URL';" /app/app/client/dist/config.js
sed -i "/var API_URL = /c\var API_URL = '$URL_PREFIX$API_URL';" /app/app/client/dist/config.js


### finaly start application
sudo -u nodejs /usr/bin/node main.js

