# PostgreSQL Primary-Replica Docker Setup

This repository provides a Docker-based PostgreSQL primary-replica setup for local development and testing. It creates two PostgreSQL instances: a primary database that can handle reads and writes, and a replica that maintains a copy of the primary's data for read-only operations.

## Prerequisites

- Docker
- Docker Compose
- Bash shell

## Repository Structure

```sh
.
├── README.md
├── docker-compose.yml
├── replicate_db.sh
├── primary/
│   ├── postgresql.conf
│   └── pg_hba.conf
└── replica/
    ├── postgresql.conf
    └── pg_hba.conf
```

## Configuration

### Primary Database

- Port: 5432
- Database: mydb
- User: myuser
- Password: mypassword

### Replica Database

- Port: 5433
- Database: mydb
- User: myuser
- Password: mypassword

## Setup Instructions

1. Clone the repository:

```bash
git clone <repository-url>
cd <repository-name>
```

2. Make the replication script executable:

```bash
chmod +x replicate_db.sh
```

3. Run the replication setup:

```bash
./replicate_db.sh
```

The script will:

- Create necessary Docker volumes
- Start the primary PostgreSQL instance
- Configure replication settings
- Create a replication user
- Set up the replica instance
- Initialize streaming replication

## Testing the Setup

1. Create a test table on the primary:

```bash
docker exec -it postgres_primary psql -U myuser -d mydb -c "CREATE TABLE test (id serial PRIMARY KEY, name text);"
```

2. Insert some data:

```bash
docker exec -it postgres_primary psql -U myuser -d mydb -c "INSERT INTO test (name) VALUES ('test1');"
```

3. Verify the data appears on the replica:

```bash
docker exec -it postgres_replica psql -U myuser -d mydb -c "SELECT * FROM test;"
```

4. Verify replication status:

```bash
docker exec -it postgres_primary psql -U myuser -d mydb -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
```

## Maintenance

### Stopping the Setup

```bash
docker-compose down
```

### Complete Cleanup (including volumes)

```bash
docker-compose down -v
```

### Restarting from Scratch

```bash
docker-compose down -v
./replicate_db.sh
```

## Common Issues and Troubleshooting

1. If containers fail to start, check Docker logs:

```bash
docker-compose logs postgres_primary
docker-compose logs postgres_replica
```

2. If replication isn't working, verify the replication slot:

```bash
docker exec -it postgres_primary psql -U myuser -d mydb -c "SELECT * FROM pg_replication_slots;"
```

3. Check replication connection status:

```bash
docker exec -it postgres_primary psql -U myuser -d mydb -c "SELECT * FROM pg_stat_replication;"
```

## Notes

- This setup is intended for local development and testing purposes
- The replica is configured for read-only operations
- Passwords are set in plain text for demonstration purposes; in production, use secure password management
- The replica will automatically attempt to reconnect if the connection to the primary is lost

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## License

[MIT License](LICENSE)
