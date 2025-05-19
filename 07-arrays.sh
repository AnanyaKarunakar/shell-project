#!/bin/bash

MOVIES=("Court" "HIT3" "Pushpa2" "Devara")

echo "First Movie: ${MOVIES[0]}"
echo "Third Movie: ${MOVIES[3]}"
echo "Fourth Movie: ${MOVIES[4]}"  # If i took unavailable element
echo "All Movies: ${MOVIES[@]}"