#!/bin/bash
docker build -t inoki-blog .
docker run -p 4000:4000 --rm inoki-blog