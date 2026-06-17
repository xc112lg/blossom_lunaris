#!/bin/bash

# Check and load environment variables from .env
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
    echo "✓ Loaded .env from current directory"
elif [ -f ../.env ]; then
    export $(cat ../.env | grep -v '#' | xargs)
    echo "✓ Loaded .env from parent directory"
else
    echo "⚠ .env file not found in current or parent directory"
fi

# Check if gh command-line tool is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI 'gh' not found. Downloading and installing..."
    wget https://github.com/cli/cli/releases/download/v2.40.1/gh_2.40.1_linux_amd64.tar.gz
    tar -xvf gh_2.40.1_linux_amd64.tar.gz
    sudo mv gh_*_linux_amd64/bin/gh /usr/local/bin/
    echo "GitHub CLI 'gh' installed successfully."
else
    echo "GitHub CLI 'gh' is already installed."
fi

# Check if user is already authenticated
if ! gh auth status &> /dev/null; then
    gh auth login --with-token $GH_TOKEN
else
    echo "Already authenticated with GitHub."
fi

# Set the version with default if not provided
version=${custom_version:-"Lunaris-AOSP-16.2-$(date '+%Y%m%d')"}

# Check if the tag already exists
if gh release view "$version" &> /dev/null; then
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

filenames=(*.zip *.img *.txt *.json)

# Create the release on GitHub
if ! gh release create "$version" --title "Release $version" --notes "Release notes"; then
    echo "Error: Failed to create the release."
    exit 1
fi

# Upload the files to the release
for filename in "${filenames[@]}"; do
    gh release upload "$version" "$filename" --clobber
done

echo "Files uploaded successfully."

# ============================================
# TELEGRAM NOTIFICATION
# ============================================

echo "Preparing to send Telegram notification..."

GITHUB_OWNER="${GITHUB_OWNER:-xc112lg}"
GITHUB_REPO="${GITHUB_REPO:-blossom_lunaris}"
RELEASE_TAG="$version"

# Build download section with filename as text only
declare -a FILE_ENTRIES

for filename in "${filenames[@]}"; do
    if [ -f "$filename" ]; then
        download_url="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/download/$RELEASE_TAG/$filename"
        file_size=$(du -h "$filename" 2>/dev/null | cut -f1)
        
        # Store: filename|url|size
        FILE_ENTRIES+=("${filename}|${download_url}|${file_size}")
    fi
done

# Create Downloads section
DOWNLOADS_SECTION="━━━━━━━━━━━━━━━━━━━
<b>📥 Downloads:</b>"

for file_entry in "${FILE_ENTRIES[@]}"; do
    filename="${file_entry%%|*}"
    remaining="${file_entry#*|}"
    url="${remaining%%|*}"
    size="${remaining##*|}"
    
    # Filename stays as TEXT ONLY, only the [GitHub] link is clickable
    DOWNLOADS_SECTION+="
🔹 ${filename}: <a href=\"${url}\">GitHub</a> (${size})"
done

DOWNLOADS_SECTION+="

━━━━━━━━━━━━━━━━━━━
<b>📲 <a href=\"https://telegra.ph/flashing-instruction-11-15\">Installation Guide</a></b>"

# Create full Telegram message
TELEGRAM_MESSAGE="<b>ProjectInfinity-X 3.11 | UNOFFICIAL📱</b>

<b>Device:</b> Blossom
<b>👨‍💻 Builder:</b> <a href=\"http://t.me/astechpro20\">AsTechpro20</a>
<b>🤖 Android Version:</b> 16 | QPR2
<b>📅 Build Date:</b> $(date '+%d/%m/%y')
<b>⚙️ <a href=\"https://t.me/ProjectInfinityX/1882\">Changelog</a></b>
<b>📸 <a href=\"https://t.me/AsTechpro20_dump/28\">Screenshots</a></b>

$DOWNLOADS_SECTION

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
else
    echo "Sending Telegram notification..."

    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": $TELEGRAM_CHAT_ID, \"text\": $(echo "$TELEGRAM_MESSAGE" | jq -Rs .), \"parse_mode\": \"HTML\"}" \
        "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage")

    if echo "$RESPONSE" | grep -q '"ok":true'; then
        echo "✓ Telegram notification sent successfully!"
    else
        echo "✗ Failed to send Telegram notification"
        echo "Response: $RESPONSE"
    fi
fi
