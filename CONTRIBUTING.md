# contributing

## requirements

- [nix](https://nixos.org/)

## getting started

```sh
nix develop
```

with [direnv](https://direnv.net/):

```sh
ln -s .envrc.project .envrc
direnv allow
```

### run

```sh
nix run
```

with [gradle](https://gradle.org/):

```sh
gradle run
```

### format

```sh
nix fmt
```

with [ktlint](https://pinterest.github.io/ktlint/):

```sh
ktlint --format
```

### check

```sh
nix flake check
```

with [gradle](https://gradle.org/) and [ktlint](https://pinterest.github.io/ktlint/):

```sh
gradle test
ktlint
```

### build

```sh
nix build
```

with [gradle](https://gradle.org/):

```sh
gradle installDist
```

### release

with [bumper](https://trev.zip/llc/bumper):

```sh
bumper
```

releases are automatically created for [significant](https://www.conventionalcommits.org/en/v1.0.0/#summary) changes
