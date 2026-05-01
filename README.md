# TreeMaker Docker

[TreeMaker 5](https://github.com/bugfolder/TreeMaker) running in Docker with a browser-based GUI via noVNC.

## Requirements

- Docker Desktop (or Docker Engine + Compose plugin)

## First run

```bash
docker-compose up --build
```

Build takes ~5 minutes (compiles TreeMaker from source). Subsequent starts are instant.

## Daily use

```bash
docker-compose up
```

Open **http://localhost:6080** in your browser. The TreeMaker window appears in the noVNC canvas.

```bash
docker-compose down   # stop
```

## Saving files

The `./files` directory next to `docker-compose.yml` is mounted at `/files` inside the container. When saving a `.tmd` file, navigate to `/files` in the file dialog to persist it on your host machine.

## Rebuilding after source changes

```bash
docker-compose up --build
```
