#!/bin/bash

# Function to convert a single digit or dot to ASCII art
convert_to_ascii() {
    case "$1" in
        0)
            echo "  ____  "
            echo " / __ \ "
            echo "| |  | |  "
            echo "| |__| | "
            echo " \____/ "
            ;;
        1)
            echo "  __ "
            echo " /_ |"
            echo "  | |"
            echo "  | |"
            echo "  |_|"
            ;;
        2)
            echo "  ____  "
            echo " |___ \ "
            echo "   __) |"
            echo "  / __/ "
            echo " |_____|"
            ;;
        3)
            echo "  _____  "
            echo " |___ /  "
            echo "   |_ \  "
            echo "  ___) | "
            echo " |____/  "
            ;;
        4)
            echo " _  _   "
            echo "| || |  "
            echo "| || |_ "
            echo "|__   _|"
            echo "   |_|  "
            ;;
        5)
            echo " ____  "
            echo "| ___| "
            echo "|___ \ "
            echo " ___) |"
            echo "|____/ "
            ;;
        6)
            echo "  __   "
            echo " / /_  "
            echo "| '_ \ "
            echo "| (_) |"
            echo " \___/ "
            ;;
        7)
            echo " _____ "
            echo "|___  |"
            echo "   / / "
            echo "  / /  "
            echo " /_/   "
            ;;
        8)
            echo "  ___  "
            echo " ( _ ) "
            echo " / _ \ "
            echo "| (_) |"
            echo " \___/ "
            ;;
        9)
            echo "  ___  "
            echo " / _ \ "
            echo "| (_) |"
            echo " \__, |"
            echo "  _/_/ "
            ;;
        .)
            echo "    "
            echo "    "
            echo "  _ "
            echo " (_)"
            echo "    "
            ;;
        *)
            echo " "
            echo " "
            echo " "
            echo " "
            echo " "
            ;;
    esac
}

# Get the IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Print the IP address in ASCII art
echo "Your IP address is: $IP_ADDRESS"

# Prepare an array to hold the lines of ASCII art
declare -a ascii_lines

# Initialize the array with empty strings
for (( i=0; i<5; i++ )); do
    ascii_lines[$i]=""
done

# Loop through each character in the IP address
for (( i=0; i<${#IP_ADDRESS}; i++ )); do
    # Get the ASCII art for the current character
    ascii_art=$(convert_to_ascii "${IP_ADDRESS:$i:1}")
    
    # Split the ASCII art into lines and append to the corresponding ascii_lines elements
    IFS=$'\n' read -r -d '' -a lines <<< "$ascii_art"
    for (( j=0; j<5; j++ )); do
        ascii_lines[$j]+="${lines[$j]}  "
    done
done

# Print each line of the combined ASCII art
for line in "${ascii_lines[@]}"; do
    echo "$line"
done
