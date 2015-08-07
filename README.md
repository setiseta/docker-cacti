# Cacti Docker

Cacti Container to use with external mysql, supported is samersbn/mysql or mysql

TODO: plugin / extension support / adding etc.

---
Usage example
===
### Needed directories on host:
- data
- mysql

### with sameersbn/mysql as database

```bash
NAME="cacti"
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
docker run -d -m 1g \
	-v $DIR/mysql:/var/lib/mysql \
	-e DB_USER=$NAME \
	-e DB_PASS=$NAME-pwd \
	-e DB_NAME=$NAME \
	--name $NAME-db \
	sameersbn/mysql:latest
```
---
```bash
NAME="cacti"
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
docker run -d \
	-v $DIR/data:/data \
	-p 80:80 \
	--link $NAME-db:mysql \
	--name $NAME \
	seti/cacti
```