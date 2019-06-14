#!/bin/bash

set -e

cd /home/intermine/intermine

# Empty log
echo "" > /home/intermine/intermine/build.progress


# Check if mine exists
if [ ! -d biotestmine ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Clone biotestmine" >> /home/intermine/intermine/build.progress
    git clone https://github.com/intermine/biotestmine
    echo "$(date +%Y/%m/%d-%H:%M) Update keyword_search.properties to use http://solr" >> /home/intermine/intermine/build.progress
    sed -i "s/localhost/solr/g" ./biotestmine/dbmodel/resources/keyword_search.properties
else
    echo "$(date +%Y/%m/%d-%H:%M) Update biotestmine to newest version" >> /home/intermine/intermine/build.progress
    cd biotestmine
    git pull
    cd /home/intermine/intermine
fi

if [ ! -f /home/intermine/.intermine/biotestmine.properties ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Copy biotestmine.properties to ~/.intermine/biotestmine.properties" >> /home/intermine/intermine/build.progress
    cp /home/intermine/intermine/biotestmine/data/biotestmine.properties /home/intermine/.intermine/

    echo -e "$(date +%Y/%m/%d-%H:%M) Set properties in .intermine/biotestmine.properties to\nPSQL_DB_NAME\tbiotestmine\nPSQL_USER\t$PSQL_USER\nPSQL_PWD\t$PSQL_PWD\nTOMCAT_USER\t$TOMCAT_USER\nTOMCAT_PWD\t$TOMCAT_PWD" >> /home/intermine/intermine/build.progress

    #sed -i "s/PSQL_PORT/$PGPORT/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/PSQL_DB_NAME/${MINE_NAME:-biotestmine}/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/PSQL_USER/${PSQL_USER:-postgres}/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/PSQL_PWD/${PSQL_PWD:-postgres}/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/TOMCAT_USER/${TOMCAT_USER:-tomcat}/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/TOMCAT_PWD/${TOMCAT_PWD:-tomcat}/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/webapp.deploy.url=http:\/\/localhost:8080/webapp.deploy.url=http:\/\/tomcat:${TOMCAT_PORT:-8080}/g" /home/intermine/.intermine/biotestmine.properties
    sed -i "s/serverName=localhost/serverName=postgres:${PGPORT:-5432}/g" /home/intermine/.intermine/biotestmine.properties


    # echo "project.rss=http://localhost:$WORDPRESS_PORT/?feed=rss2" >> /home/intermine/.intermine/biotestmine.properties
    # echo "links.blog=https://localhost:$WORDPRESS_PORT" >> /home/intermine/.intermine/biotestmine.properties
fi

if [ ! -f /home/intermine/biotestmine/project.xml ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Copy project.xml to ~/biotestmine/project.xml" >> /home/intermine/intermine/build.progress
    cp /home/intermine/intermine/biotestmine/data/project.xml /home/intermine/intermine/biotestmine/

    echo "$(date +%Y/%m/%d-%H:%M) Set correct source path in project.xml" >> /home/intermine/intermine/build.progress
    sed -i 's/DATA_DIR/\/home\/intermine\/intermine\/data/g' /home/intermine/intermine/biotestmine/project.xml
fi

if [ ! -d /home/intermine/intermine/data/malaria ]; then
    echo "$(date +%Y/%m/%d-%H:%M) Copy malria-data to ~/data" >> /home/intermine/intermine/build.progress
    cp /home/intermine/intermine/biotestmine/data/malaria-data.tar.gz /home/intermine/intermine/data/
    cd /home/intermine/intermine/data/
    tar -xf malaria-data.tar.gz
    rm malaria-data.tar.gz
    cd /home/intermine/intermine
fi

echo "$(date +%Y/%m/%d-%H:%M) Connect and create Postgres databases" >> /home/intermine/intermine/build.progress

# # Wait for database
# dockerize -wait tcp://postgres:$PGPORT -timeout 60s

# Close all open connections to database
psql -U postgres -h postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid();"

echo "$(date +%Y/%m/%d-%H:%M) Database is now available ..." >> /home/intermine/intermine/build.progress
echo "$(date +%Y/%m/%d-%H:%M) Reset databases and roles" >> /home/intermine/intermine/build.progress

# Delete Databases if exist
psql -U postgres -h postgres -c "DROP DATABASE IF EXISTS \"biotestmine\";"
psql -U postgres -h postgres -c "DROP DATABASE IF EXISTS \"items-biotestmine\";"
psql -U postgres -h postgres -c "DROP DATABASE IF EXISTS \"userprofile-biotestmine\";"

# psql -U postgres -h postgres -c "DROP ROLE IF EXISTS ${PSQL_USER:-postgres};"

# Create Databases
echo "$(date +%Y/%m/%d-%H:%M) Creating postgres database tables and roles.." >> /home/intermine/intermine/build.progress
# psql -U postgres -h postgres -c "CREATE USER ${PSQL_USER:-postgres} WITH PASSWORD '${PSQL_PWD:-postgres}';"
psql -U postgres -h postgres -c "ALTER USER ${PSQL_USER:-postgres} WITH SUPERUSER;"
psql -U postgres -h postgres -c "CREATE DATABASE \"biotestmine\";"
psql -U postgres -h postgres -c "CREATE DATABASE \"items-biotestmine\";"
psql -U postgres -h postgres -c "CREATE DATABASE \"userprofile-biotestmine\";"
psql -U postgres -h postgres -c "GRANT ALL PRIVILEGES ON DATABASE biotestmine to ${PSQL_USER:-postgres};"
psql -U postgres -h postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"items-biotestmine\" to ${PSQL_USER:-postgres};"
psql -U postgres -h postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"userprofile-biotestmine\" to ${PSQL_USER:-postgres};"


cd biotestmine

echo "$(date +%Y/%m/%d-%H:%M) Gradle: buildDB" >> /home/intermine/intermine/build.progress
./gradlew buildDB --stacktrace >> /home/intermine/intermine/build.progress

echo "$(date +%Y/%m/%d-%H:%M) Gradle: integrate uniprot-malaria" >> /home/intermine/intermine/build.progress
./gradlew integrate -Psource=uniprot-malaria --stacktrace

echo "$(date +%Y/%m/%d-%H:%M) Gradle: integrate malaria-gff" >> /home/intermine/intermine/build.progress
./gradlew integrate -Psource=malaria-gff --stacktrace

echo "$(date +%Y/%m/%d-%H:%M) Gradle: integrate malaria-chromosome-fasta" >> /home/intermine/intermine/build.progress
./gradlew integrate -Psource=malaria-chromosome-fasta --stacktrace

echo "$(date +%Y/%m/%d-%H:%M) Gradle: integrate entrez-organism" >> /home/intermine/intermine/build.progress
./gradlew integrate -Psource=entrez-organism --stacktrace

echo "$(date +%Y/%m/%d-%H:%M) Gradle: integrate update-publications" >> /home/intermine/intermine/build.progress
./gradlew integrate -Psource=update-publications --stacktrace >> /home/intermine/intermine/build.progress

echo "$(date +%Y/%m/%d-%H:%M) Gradle: run post_processess" >> /home/intermine/intermine/build.progress
./gradlew postProcess --stacktrace >> /home/intermine/intermine/build.progress

echo "$(date +%Y/%m/%d-%H:%M) Gradle: build userDB" >> /home/intermine/intermine/build.progress
./gradlew buildUserDB --stacktrace >> /home/intermine/intermine/build.progress

echo "$(date +%Y/%m/%d-%H:%M) Gradle: build webapp" >> /home/intermine/intermine/build.progress
./gradlew clean
./gradlew cargoRedeployRemote  --stacktrace >> /home/intermine/intermine/build.progress