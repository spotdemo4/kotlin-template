# kotlin template

[![check](https://trev.zip/template/kotlin/actions/workflows/check.yaml/badge.svg?branch=main&logo=forgejo&logoColor=%23bac2de&label=check&labelColor=%23313244)](https://trev.zip/template/kotlin/actions?workflow=check.yaml)
[![vulnerable](https://trev.zip/template/kotlin/actions/workflows/vulnerable.yaml/badge.svg?branch=main&logo=forgejo&logoColor=%23bac2de&label=vulnerable&labelColor=%23313244)](https://trev.zip/template/kotlin/actions?workflow=vulnerable.yaml)
[![kotlin](<https://img.shields.io/badge/dynamic/regex?url=https://trev.zip/template/kotlin/raw/branch/main/build.gradle.kts&search=kotlin%5C(%22jvm%22%5C)%20version%20%22(.*)%22&replace=%241&logo=kotlin&logoColor=%23bac2de&label=version&labelColor=%23313244&color=%237F52FF>)](https://kotlinlang.org/docs/releases.html)

template for starting [kotlin](https://kotlinlang.org/) projects

part of [spotdemo4/templates](https://github.com/spotdemo4/templates)

## requirements

- [nix](https://nixos.org/)

## getting started

```sh
nix develop
./init.sh "Title" "Description"
```

### run

```sh
nix run .#dev
```

### format

```sh
nix fmt
```

### check

```sh
nix flake check
```

### build

```sh
nix build
```

### release

```sh
bumper
```

releases are automatically created for [significant](https://www.conventionalcommits.org/en/v1.0.0/#summary) changes

## use

### docker

```sh
docker run trev.zip/template/kotlin:latest
```

### nix

```sh
nix run git+https://trev.zip/template/kotlin.git
```

### download

https://trev.zip/template/kotlin/releases
