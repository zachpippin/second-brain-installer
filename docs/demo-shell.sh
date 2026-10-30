#!/bin/sh
# Login-free shell for docs/demo.tape.
# Clears the parent environment so the recording cannot inherit a real
# home directory, username, or hostname, then starts bash.
exec /usr/bin/env -i \
  HOME=/home/demo \
  USER=demo \
  LOGNAME=demo \
  HOSTNAME=kit \
  TERM=xterm-256color \
  LANG=C.UTF-8 \
  BUN_INSTALL=/home/demo/.bun \
  PATH=/home/demo/.bun/bin:/usr/bin:/bin \
  /bin/bash --noprofile --norc
