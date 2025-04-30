#!/bin/bash

# Function to prompt for input if not provided as arguments
prompt_for_input() {
    if [ -z "$username_input" ]; then
        read -p "Enter username (user1/user2): " username_input
    fi
    if [ -z "$ip_suffix" ]; then
        read -p "Enter IP suffix (e.g., suffix1): " ip_suffix
    fi
}

# Check if arguments are provided
username_input="$1"
ip_suffix="$2"

# Prompt for input if not provided as arguments
prompt_for_input

# Set username based on input
case "$username_input" in
    user1)
        username="user1"
        password="password1"
        ;;
    user2)
        username="user2"
        password="password2"
        ;;
    *)
        echo "Invalid username input"
        exit 1
        ;;
esac

# Set server_ip based on IP suffix
case "$ip_suffix" in
    suffix1)
        server_ip="192.168.suffix1"
        ;;
    suffix2)
        server_ip="192.168.suffix2"
        ;;
    suffix3)
        server_ip="192.168.suffix3"
        ;;
    *)
        echo "Invalid IP suffix"
        exit 1
        ;;
esac

# Connect to the server using SSH
sshpass -p "$password" ssh "$username"@"$server_ip"
