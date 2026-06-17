#!/bin/bash

# Check and load environment variables from .env
# First check in current directory, then parent directory
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
    echo "✓ Loaded .env from current directory"
elif [ -f ../.env ]; then
    export $(cat ../.env | grep -v '#' | xargs)
    echo "✓ Loaded .env from parent directory"
else
    echo "⚠ .env file not found in current or parent directory"
    echo "Please create .env in /tmp/src/android/ or /tmp/src/android/blossom_lunaris/"
fi

# Rest of the original script continues...
# Check if gh command-line tool is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI 'gh' not found. Downloading and installing..."
    wget https://github.com/cli/cli/releases/download/v2.94.0/gh_2.94.0_linux_amd64.tar.gz
    tar -xvf gh_2.94.0_linux_amd64.tar.gz
    sudo mv gh_*_linux_amd64/bin/gh /usr/local/bin/
    echo "GitHub CLI 'gh' installed successfully."
else
    echo "GitHub CLI 'gh' is already installed."
fi

# Check if user is already authenticated
if ! gh auth status &> /dev/null; then
    # User not authenticated, perform login
    gh auth login --with-token $GH_TOKEN
else
    echo "Already authenticated with GitHub."
fi

# Set the version with default if not provided
version=${custom_version:-"Lunaris-AOSP-16.2-$(date '+%Y%m%d')"}

# Check if the tag already exists
if gh release view "$version" &> /dev/null; then
    # Tag exists, ask for confirmation to delete the tag and releases
    echo "Deleting existing tag and releases for $version..."
    gh release delete "$version" --yes
    git tag -d "$version"
    git push origin --delete "$version"
    echo "Existing tag and releases deleted."
fi

# Create the new tag and push it to GitHub
git tag -a "$version" -m "Release $version"
git push origin "$version" --force

# Initialize an array to store the filenames
declare -a filenames

# Uncomment the following block if you want to upload all .zip and .img files in the current directory
 filenames=(*.zip *.img *.txt *.json)

# Otherwise, ask the user to input the filenames
# read -p "Enter the filenames (separated by spaces): " -a filenames

# Create the release on GitHub
if ! gh release create "$version" --title "Release $version" --notes "Release notes"; then
    echo "Error: Failed to create the release."
    exit 1
fi

# Upload the files to the release
for filename in "${filenames[@]}"; do
    gh release upload "$version" "$filename" --clobber
done

# Display success message
echo "Files uploaded successfully."

# ============================================
# TELEGRAM NOTIFICATION
# ============================================

echo "Preparing to send Telegram notification..."

# Telegram configuration (from .env)
GITHUB_OWNER="${GITHUB_OWNER:-xc112lg}"
GITHUB_REPO="${GITHUB_REPO:-blossom_lunaris}"
RELEASE_TAG="$version"

# Build download links for files
declare -a DOWNLOAD_LINKS

for filename in "${filenames[@]}"; do
    if [ -f "$filename" ]; then
        download_url="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/download/$RELEASE_TAG/$filename"
        DOWNLOAD_LINKS+=("$filename|$download_url")
    fi
done

# Create Telegram message with download links
TELEGRAM_MESSAGE="<b>ProjectInfinity-X 3.11 | UNOFFICIAL📱</b>

<b>Device:</b> Blossom
<b>👨‍💻 Builder:</b> <a href=\"http://t.me/astechpro20\">AsTechpro20</a>
<b>🤖 Android Version:</b> 16 | QPR2
<b>📅 Build Date:</b> $(date '+%d/%m/%y')
<b>⚙️ <a href=\"https://t.me/ProjectInfinityX/1882\">Changelog</a></b>
<b>📸 <a href=\"https://t.me/AsTechpro20_dump/28\">Screenshots</a></b>

━━━━━━━━━━━━━━━━━━━
<b>📥 Downloads:</b>"

# Add file download links dynamically
for link_pair in "${DOWNLOAD_LINKS[@]}"; do
    filename="${link_pair%|*}"
    url="${link_pair#*|}"
    file_size=$(du -h "$filename" 2>/dev/null | cut -f1)
    
    # Categorize files
    if [[ "$filename" == *"vanilla"* ]]; then
        TELEGRAM_MESSAGE+="
🔹 <b>Vanilla:</b> <a href=\"$url\">GitHub</a> ($file_size) | <a href=\"https://gofile.io/d/6V4MyK\">Gofile</a>"
    elif [[ "$filename" == *"gapps"* ]] || [[ "$filename" == *"GApps"* ]]; then
        TELEGRAM_MESSAGE+="
🔹 <b>GApps:</b> <a href=\"$url\">GitHub</a> ($file_size) | <a href=\"https://gofile.io/d/E9w9Vz\">Gofile</a>"
    else
        TELEGRAM_MESSAGE+="
🔹 <b>$filename:</b> <a href=\"$url\">GitHub</a> ($file_size)"
    fi
done

TELEGRAM_MESSAGE+="

━━━━━━━━━━━━━━━━━━━
<b>📲 <a href=\"https://telegra.ph/flashing-instruction-11-15\">Installation Guide</a></b>

━━━━━━━━━━━━━━━━━━━
<b>🐞 Issues:</b>
• NFC is not working

━━━━━━━━━━━━━━━━━━━
<b>📝 Notes:</b>
• Both GApps & Vanilla are available
• Signed build
• Includes MIUI Camera & Lunari Dolby
• June security patch
• Default Kernel Sashimi

━━━━━━━━━━━━━━━━━━━
<b>❤️ Credits & Thanks:</b>
• Yui Onanii, fukiame, @snnbyyds, <a href=\"http://t.me/Sushrut1101\">Sushrut</a>, xiaomi-blossom-dev contributors for base tree
• Thanks to <a href=\"http://t.me/nya_toru0w0\">Noi</a> for server
• Special Thanks to 0kaarun & Yohan Yuan for their help
• Thanks to all other devs

━━━━━━━━━━━━━━━━━━━
<b>🌐 Stay Updated:</b>
📢 @AsTechpro20_lab
📢 @AsTechpro20_dump
📢 @AsTechpro20_lab_support

━━━━━━━━━━━━━━━━━━━
#blossom #UNOFFICIAL #projectinfinityx #infinityx #lunaridolby #Rom"

# Send Telegram message
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "⚠ Telegram credentials not set. Skipping Telegram notification."
    echo "Make sure .env contains TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID"
else
    echo "Sending Telegram notification..."

    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": $TELEGRAM_CHAT_ID, \"text\": $(echo "$TELEGRAM_MESSAGE" | jq -Rs .), \"parse_mode\": \"HTML\"}" \
        "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage")

    # Check if message was sent successfully
    if echo "$RESPONSE" | grep -q '"ok":true'; then
        echo "✓ Telegram notification sent successfully!"
    else
        echo "✗ Failed to send Telegram notification"
        echo "Response: $RESPONSE"
    fi
fi
