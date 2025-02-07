#!/bin/bash

# README! Dopo ogni esecuzione dello script ./racadm_scipt.sh i file UNREACHABLE_IPS_FILE e UNKNOWN_PASSWORD verranno sovrascritti! E' consigliabile quindi un backup degli stessi.

USERNAME="root"
PASSWORD1="IPMI@R3c4S"
PASSWORD2="calvin"

SERVER_LIST="server_list"
UNREACHABLE_IPS_FILE="unreachable_ipmi.txt"
UNKNOWN_PASSWORD="unknown_passwords.txt"

touch $UNREACHABLE_IPS_FILE
touch $UNKNOWN_PASSWORD

> "$UNREACHABLE_IPS_FILE"
> "$UNKNOWN_PASSWORD"

if [[ ! -f $SERVER_LIST ]]; then
  echo "Error: $SERVER_LIST file not found!"
  exit 1
fi

echo "Reading server list..."
cat "$SERVER_LIST"

while IFS= read -r SERVER_IP || [[ -n "$SERVER_IP" ]]; do
  echo "Processing: $SERVER_IP"

  if [[ -z "$SERVER_IP" ]]; then
    echo "Skipping empty line..."
    continue
  fi

  echo "Trying ping"
  ping -c 1 "$SERVER_IP" &> /dev/null


  if [ $? -eq 0 ]; then
    echo "$SERVER_IP is reachable, proceeding with SSH connection..."

    sshpass -p "$PASSWORD1" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$SERVER_IP << EOF
racadm set iDRAC.IPMILan.Enable 1
exit
EOF

  SSH_EXIT_STATUS=$?

  if [[ -z "$SSH_EXIT_STATUS" ]]; then
    SSH_EXIT_STATUS="1"  # If no exit status was set, default to 1 (failure)
  fi

  if [ "$SSH_EXIT_STATUS" -eq 0 ]; then
    echo "Successfully applied command on $SERVER_IP with first password"
  else
    echo "First password failed on $SERVER_IP. Trying second password..."

    sshpass -p "$PASSWORD2" ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$SERVER_IP << EOF
racadm set iDRAC.IPMILan.Enable 1
exit
EOF

      SSH_EXIT_STATUS=$?

      if [[ -z "$SSH_EXIT_STATUS" ]]; then
        SSH_EXIT_STATUS="1"
      fi

      if [ "$SSH_EXIT_STATUS" -eq 0 ]; then
        echo "Successfully applied command on $SERVER_IP with second password"
      else
        echo "Both passwords failed to apply command on $SERVER_IP"
        echo "$SERVER_IP" >> "$UNKNOWN_PASSWORD"
      fi
    fi

  else
    # Log the unreachable IP to the file
    echo "$SERVER_IP is not reachable. Logging to unreachable_ipmi.txt..."
    echo "$SERVER_IP" >> "$UNREACHABLE_IPS_FILE"
  fi

done < "$SERVER_LIST"
