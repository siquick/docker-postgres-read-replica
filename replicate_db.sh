#!/bin/bash

set -e  # Exit on error

# Function to wait for PostgreSQL to be ready
wait_for_postgres() {
    local host=$1
    local max_attempts=30
    local attempt=1

    echo "Waiting for PostgreSQL at $host to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if docker exec $host pg_isready -U myuser; then
            echo "PostgreSQL at $host is ready!"
            return 0
        fi
        echo "Attempt $attempt of $max_attempts: PostgreSQL at $host is not ready yet..."
        attempt=$((attempt + 1))
        sleep 1
    done
    echo "Failed to connect to PostgreSQL at $host after $max_attempts attempts"
    return 1
}

echo "Cleaning up any existing containers..."
docker-compose down -v

echo "Starting primary database..."
docker-compose up -d postgres_primary

# Wait for primary to be ready
wait_for_postgres "postgres_primary"

# Configure pg_hba.conf for replication
echo "Configuring pg_hba.conf..."
docker exec postgres_primary bash -c 'echo "host replication replicator all md5" >> /var/lib/postgresql/data/pg_hba.conf'
docker exec postgres_primary bash -c 'echo "host all all all md5" >> /var/lib/postgresql/data/pg_hba.conf'

# Reload PostgreSQL configuration as postgres user
docker exec -u postgres postgres_primary pg_ctl reload

# Create replication user and slot on primary
echo "Setting up replication user and slot..."
docker exec postgres_primary psql -U myuser -d mydb -c "DO \$\$ 
BEGIN 
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'replicator') THEN
        CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replicatorpass';
    END IF;
END \$\$;"

docker exec postgres_primary psql -U myuser -d mydb -c "DO \$\$ 
BEGIN 
    IF NOT EXISTS (SELECT FROM pg_replication_slots WHERE slot_name = 'replica_slot') THEN
        PERFORM pg_create_physical_replication_slot('replica_slot');
    END IF;
END \$\$;"

# Create a volume for the replica
echo "Setting up replica volume..."
docker volume create parade-db_postgres_replica_data

# Create base backup and copy to volume in one step
echo "Creating base backup and preparing replica data directory..."
docker run --rm \
    --network parade-db_default \
    -e PGPASSWORD=replicatorpass \
    -v parade-db_postgres_replica_data:/var/lib/postgresql/data \
    --name temp_backup \
    postgres:15 \
    bash -c "pg_basebackup -h postgres_primary -D /var/lib/postgresql/data -U replicator -v -P -R && chown -R postgres:postgres /var/lib/postgresql/data"

echo "Starting replica with new configuration..."
docker-compose up -d postgres_replica

# Wait for replica to be ready
wait_for_postgres "postgres_replica"

# Verify replication is working
echo "Verifying replication status..."
docker exec postgres_primary psql -U myuser -d mydb -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"

echo "Setup complete!"
