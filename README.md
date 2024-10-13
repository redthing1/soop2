# soop2
*the based http fileserver*

soop2 originated as a "better" clone of python's `http.server` cli tool. soop2 has all those features and more, and fixes my problems and adds features i wish i had before.

## features

+ http file browsing with minimalist ui
+ http file upload (POST) support
+ configuration from toml file
+ support for http basic auth for uploads/downloads/both
+ use as a [cli tool](#cli-tool)
+ use as a [configurable server](#configuration)

## build

build default debug-mode binary:
```sh
dub build
```

build optimized binary:
```sh
dub build -B release --compiler=ldc2 -c optim
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

## usage

### cli tool

use it to rapidly spin up a local http server.
```
soop2: the based http fileserver (v0.6.2)

USAGE
  $ soop2 [options] public_dir

FLAGS
  -h, --help                prints help
      --version             prints version
  -u, --enable-upload       enable file uploads
  -v, --verbose             turns on more verbose output
  -q, --quiet               reduces output LoggerVerbosity

OPTIONS
  -c, --config-file value   config file to use
  -l, --host value          host to listen on
  -p, --port value          config file to use

ARGUMENTS
  public_dir                public directory
```

example: serve the current directory on port 8000 with uploads enabled:
```sh
soop2 . -p 8000 -u
```

### configuration

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
