# Sui-Basecamp-WriteUp

[Sui Basecamp CTF](https://basecamp.osec.io/) WriteUp by zeroc

## Setup your local environment
```bash
brew install libpq
brew link --force libpq
docker build -t . sui-postgres
docker run -d -p 5432:5432 --name test sui-postgres:latest
cd xxx/framework && cargo r --release
```