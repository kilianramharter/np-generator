#!/bin/bash

TARGET_DIR="/home/student/bind/"
ZONES_DIR="zones"
OPTIONS_FILE="named.conf.options"
LOCAL_FILE="named.conf.local"
DEMO_RUN=1

# Get list of files (without directories)
mapfile -t files < <(find "$TARGET_DIR$ZONES_DIR" -maxdepth 1 -type f)

# Check if files exist
if [ ${#files[@]} -eq 0 ]; then
  echo "No zone files found in directory: $TARGET_DIR$ZONES_DIR"
  exit 1
fi

# Display files with index
# echo "Select one or more zones by typing their numbers (space-separated):"
echo -e "\n\e[1m==== DNSSEC AUTOCONFIG ====\e[0m"
echo -e "Select one or more zones:\n"


# Map index to short names
shortnames=()
for i in "${!files[@]}"; do
  filename="${files[i]}"
  shortname=$(echo "$filename" | sed -E 's|.*/db\.([^/]+)\.zone$|\1|')
  shortnames+=("$shortname")
  # echo "[$((i+1))] $shortname"
  echo -e "\e[1;32m[$((i+1))]\e[0m $shortname"
done

# Read user input
echo -e ""
read -p "Enter zone numbers: " -a selection

# Store selected shortnames only
selected_files=()
for index in "${selection[@]}"; do
  if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -ge 1 ] && [ "$index" -le "${#shortnames[@]}" ]; then
    selected_files+=("${shortnames[$((index-1))]}")
  else
    echo -e "\e[1;31mInvalid selection:\e[0m $index"
    exit 1
  fi
done

# Loop through filenames and run DNSSEC commands
echo -e "\n\e[1m==== Configuring DNSSEC ===\e[0m"

echo -n "Checking if dnssec-validation is enabled... "
if grep -q "dnssec-validation no;" "$TARGET_DIR$OPTIONS_FILE"; then
  echo -e "\e[1;31mnot enabled\e[0m"
  echo -n "Enabling dnssec-validation... "
  sed -i 's/dnssec-validation no;/dnssec-validation yes;/' "$TARGET_DIR$OPTIONS_FILE"
  echo -e "\e[1;32menabled\e[0m"
else
  echo -e "\e[1;32malready enabled\e[0m"
fi
echo ""

for file in "${selected_files[@]}"; do
  echo -en "\e[1m[$file]\e[0m Generating KSK... "
  if [ $DEMO_RUN -eq "0" ]; then
    # KSK generation here
    # dnssec-keygen -a RSASHA256 -b 2048 -f KSK -n ZONE "${file}."
    dnssec-keygen -a RSASHA256 -b 2048 -f KSK -n ZONE "${file}." -K "$TARGET_DIR$ZONES_DIR"
    sleep 0
  else
    sleep 1
  fi
  echo -e "\e[1;32mdone\e[0m"

  echo -en "\e[1m[$file]\e[0m Generating ZSK... "
  if [ $DEMO_RUN -eq "0" ]; then
    # ZSK generation here
    # dnssec-keygen -a RSASHA256 -b 1024 -n ZONE "${file}."
    dnssec-keygen -a RSASHA256 -b 1024 -n ZONE "${file}." -K "$TARGET_DIR$ZONES_DIR"
    sleep 0
  else
    sleep 1
  fi
  echo -e "\e[1;32mdone\e[0m"

  echo -en "\e[1m[$file]\e[0m Signing zone file... "
  if [ $DEMO_RUN -eq "0" ]; then
    # Zone signing here
    # dnssec-signzone -A -3 "$(openssl rand -hex 8)" -N increment -o "${file}" "db.${file}.zone"
    dnssec-signzone -A -3 "$(openssl rand -hex 8)" -N increment -o "${file}" -K "$TARGET_DIR$ZONES_DIR" "$TARGET_DIR$ZONES_DIR/db.${file}.zone"
    sleep 0
  else
    sleep 1
  fi
  echo -e "\e[1;32mdone\e[0m"

  echo -en "\e[1m[$file]\e[0m Updating zone definition... "
  if [ $DEMO_RUN -eq "0" ]; then
    # Zone definition update here

    # Replace db.website.com.zone with db.website.com.zone.signed in the named.conf.local
    # Only replace if it uses the unsigned zone
    if grep -q "file \"$TARGET_DIR$ZONES_DIR/db.${file}.zone\";" "$TARGET_DIR$LOCAL_FILE"; then
        sed -i "s|file \"$TARGET_DIR$ZONES_DIR/db\.${file}\.zone\";|file \"$TARGET_DIR$ZONES_DIR/db.${file}.zone.signed\";|" "$TARGET_DIR$LOCAL_FILE"
        echo -e "\e[1;32mdone\e[0m"
    else
        echo -e "\e[1;32mskipped\e[0m"
    fi

    sleep 0
  else
    sleep 1
    echo -e "\e[1;32mdone\e[0m"
  fi  

  if [ $DEMO_RUN -eq "0" ]; then
    # Retrieve DS record from KSK file
    signed_zone_file="$TARGET_DIR$ZONES_DIR/db.${file}.zone.signed"
    if [[ -f "$signed_zone_file" ]]; then
        ds_record=$(dnssec-dsfromkey -f "$signed_zone_file")
        echo -e "\nPaste this DS record in the parent of the '$file' zone:"
        echo "$ds_record"
    else
        echo -e "\e[1;31mError:\e[0m Signed zone file not found for '$file'"
    fi
  else
    echo "Paste this DS record in the parent of the '$file' zone:"
    echo "$file.   IN DS <org-KSK-keytag> <alg> <digest-type> <digest>"
  fi
  
  echo ""
done
