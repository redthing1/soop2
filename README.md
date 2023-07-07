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
