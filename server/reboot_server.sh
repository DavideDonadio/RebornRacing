#!/bin/bash

echo "Stopping server-manager..."
pkill -f "./server-manager"

echo "Stopping real penalty plugin..."
pkill -f "ac_penalty"

sleep 2

echo "Starting server-manager with nohup..."
nohup ./server-manager >> server.log 2>&1 &

echo "Done."

