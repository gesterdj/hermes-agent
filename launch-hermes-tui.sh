#! /bin/bash

docker exec -it \
   --user "$(id -u):$(id -g)" \
   -e HOME=/opt/data/home \
   -e HERMES_HOME=/opt/data \
   -e HERMES_TUI_DIR=/opt/hermes/ui-tui \
   hermes /opt/hermes/.venv/bin/hermes --tui
