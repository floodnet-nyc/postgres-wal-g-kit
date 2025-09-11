# Postgres + WAL-G Restore Kit
Test an existing PostgreSQL backup locally.

It uses a custom image with a couple features:
 * built wal-g binary
 * timescaledb base image (should work normal postgres base image too?)
 * `wal-g-env` wrapper script for multi-storage location setups (e.g. restore from azure, archive locally)
    * `wal-g-env some_env backup-list` is equivalent to `WALG_XX_PREFIX=$WALG_SOME_ENV_PREFIX wal-g backup-list`

## Install
Configure your storage credentials using environment variables (following the instructions inside):
```bash
cp .env.sample .env
```

Start the restore process:
```bash
docker compose up -d --build
```

### Re-run with the latest backup
```bash
docker compose down
rm -r data  # or: mv data data1
docker compose up -d
```

## Do a full base backup from this local copy
```bash
# echo 'WALG_PUSH_PREFIX=/backups' >> .env  # if you aren't already
docker exec -it postgres-wal-g-kit wal-g-env push backup-push /var/lib/postgresql/data
```

### Test the local base backup
```bash
# clear
docker compose down
rm -r data  # or: mv data data1

# fetch from local
echo 'WALG_FETCH_PREFIX=/backups' >> .env

# bring it back up
docker compose up -d
```


## Manually restore

### List available backups
```bash
docker exec -it postgres-wal-g-kit wal-g-env fetch backup-list --pretty --detailed
```

### Pull backup to new location
```bash
docker run -it --rm -v ${PWD}/data2:/backup --env-file .env postgres-wal-g-kit wal-g-env fetch backup-fetch /backup LATEST
```

### Pull incremental backups

TODO pull incremental/wal/etc.?

```bash
# docker exec -it postgres-wal-g-kit wal-g-env fetch catchup-list
# docker exec -it postgres-wal-g-kit wal-g-env fetch catchup-fetch /var/lib/postgresql/data backup_name
# docker exec -it postgres-wal-g-kit wal-g-env fetch wal-show
```


## Uninstall
```bash
docker compose down
rm -r ./data ./backups
```

## wal-g usage
```bash
PostgreSQL backup tool

Usage:
wal-g [command]

Available Commands:
backup-fetch    Fetches a backup from storage
backup-list     Prints full list of backups from which recovery is available
backup-mark     Marks a backup permanent or impermanent
backup-push     Makes backup and uploads it to storage
catchup-fetch   Fetches an incremental backup from storage
catchup-list    Prints available incremental backups
catchup-push    Creates incremental backup from lsn
catchup-receive Receive an incremental backup from another instance
catchup-send    Sends incremental backup to standby
completion      Output shell completion code for the specified shell
copy            copy specific or all backups
daemon          Runs WAL-G in daemon mode which executes commands sent from the lightweight walg-daemon-client.
delete          Clears old backups and WALs
flags           Display the list of available global flags for all wal-g commands
help            Help about any command
pgbackrest      Interact with pgbackrest backups (beta)
st              (DANGEROUS) Storage tools
wal-fetch       Fetches a WAL file from storage
wal-push        Uploads a WAL file to storage
wal-receive     Receive WAL stream with postgres Streaming Replication Protocol and push to storage
wal-restore     Restores WAL segments from storage.
wal-show        Show storage WAL segments info grouped by timelines.
wal-verify      Verify WAL storage folder. Available checks: integrity, timeline.

Flags:
      --config string   config file (default is $HOME/.walg.json)
  -h, --help            help for wal-g
      --turbo           Ignore all kinds of throttling defined in config
  -v, --version         version for wal-g

To get the complete list of all global flags, run: 'wal-g flags'

Use "wal-g [command] --help" for more information about a command.
```