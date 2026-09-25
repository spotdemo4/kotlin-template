# kotlin template

[![check](https://trev.zip/template/kotlin/actions/workflows/check.yaml/badge.svg?branch=main&logo=forgejo&logoColor=%23bac2de&label=check&labelColor=%23313244)](https://trev.zip/template/kotlin/actions?workflow=check.yaml)
[![vulnerable](https://trev.zip/template/kotlin/actions/workflows/vulnerable.yaml/badge.svg?branch=main&logo=forgejo&logoColor=%23bac2de&label=vulnerable&labelColor=%23313244)](https://trev.zip/template/kotlin/actions?workflow=vulnerable.yaml)
[![nixpkgs](https://nix-shield.trev.zip/?url=https://trev.zip/template/kotlin/raw/branch/main/flake.lock&input=nixpkgs&logoColor=%23bac2de&labelColor=%23313244&color=%235277C3)](https://nixos.org/)
[![kotlin](<https://img.shields.io/badge/dynamic/regex?url=https://trev.zip/template/kotlin/raw/branch/main/build.gradle.kts&search=kotlin%5C(%22jvm%22%5C)%20version%20%22(.*)%22&replace=%241&logo=kotlin&logoColor=%23bac2de&label=version&labelColor=%23313244&color=%237F52FF>)](https://kotlinlang.org/docs/releases.html)

template for starting [kotlin](https://kotlinlang.org/) projects

to initialize a new project, run:

```sh
./init.sh "Title" "Description"
```

part of [spotdemo4/templates](https://github.com/spotdemo4/templates)

## using

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

## contributing

see [CONTRIBUTING.md](CONTRIBUTING.md) for requirements and getting started
