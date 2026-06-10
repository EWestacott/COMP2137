#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Define groups and members
declare -A groups=(
    ["brews"]="coors stella michelob guiness"
    ["trees"]="oak pine cherry willow maple walnut ash apple"
    ["cars"]="chrysler toyota dodge chevrolet pontiac ford suzuki hyundai cadillac jaguar"
    ["staff"]="bill tim marilyn kevin george"
    ["admins"]="bob rob brian dennis"
)

PASSWORD_FILE="user_passwords.txt"
echo "Username:Password" > $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Create Groups
for group in "${!groups[@]}"; do
    groupadd "$group" 2>/dev/null
done

# Create Users
for group in "${!groups[@]}"; do
    for user in ${groups[$group]}; do
        # Create user with home directory and primary group
        useradd -m -g "$group" "$user" 2>/dev/null
        
        # Generate password
        PASS=$(dd if=/dev/random count=1 status=none|base64|dd bs=16 count=1 status=none)
        
        # Set password
        echo "$user:$PASS" | chpasswd
	
        # Log to file
        echo "$user:$PASS" >> $PASSWORD_FILE
    done
done

# Special configuration for Dennis
usermod -aG brews,trees,cars,staff dennis
# Assuming sudo group exists (standard in Debian/Ubuntu)
usermod -aG sudo dennis

echo "Users created. Passwords saved to $PASSWORD_FILE"
