#!/bin/bash
docker pull csima/attachments_worker
docker stop "$1"
docker rm "$1"
docker run --name worker --restart=always --env-file=docker-env -d csima/attachments_worker