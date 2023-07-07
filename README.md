# soop2

the based http fileserver

## features

+ http file browsing with minimalist ui
+ http file upload (POST) support
+ configuration from toml file
+ support for http basic auth for uploads/downloads/both

## build

build default debug-mode binary:
```sh
dub build
```

build optimized binary:
```sh
dub build -B release --compiler=ldc2 -c optim
strip soop2
```

## docker

```sh
podman build . -t soop2
```

## compose

copy `docker-compose.yml.example` to `docker-compose.yml` and edit it to your needs, including creating the necessary directories and config file. see [configuration](#configuration) for information on how to configure soop2.
```sh
docker-compose up -d
```

## configuration

soop2 can by configured by a toml file by passing `-c /path/to/config.toml`. a few options are also available by command line arguments for convenience and portable use. command line arguments take precedence over the config file.

here is a sample config file:
```toml
[server]
host = "127.0.0.1"
port = 8888
enable_upload = true

[listing]
ignore_file = ".gitignore"

[upload]
prepend_timestamp = false
```
