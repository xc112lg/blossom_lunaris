  #!/bin/bash
# --- Optimized RBE Configuration for AOSP Builds ---
# Recommendations based on your current setup and performance best practices
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
    echo "✓ Loaded .env from current directory"
elif [ -f ../.env ]; then
    export $(cat ../.env | grep -v '#' | xargs)
    echo "✓ Loaded .env from parent directory"
else
    echo "⚠ .env file not found"
fi
git config --global url."https://${GH_TOKEN}:x-oauth-basic@github.com/".insteadOf "https://github.com/"
rm -rf .repo/local_manifests/
rm -rf device/xiaomi
rm -rf kernel/xiaomi/blossom

#rm -rf build
rm -rf TMP_PATCHES
#rm -rf frameworks/base
sudo apt update >/dev/null 2>&1
sudo apt install patchelf -y >/dev/null 2>&1
rm -rf .repo/local_manifests packages/apps/Evolver vendor/extras
repo init -u https://github.com/Evolution-X/manifest -b bka --git-lfs --depth=1
git clone https://$GH_TOKEN@github.com/xc112lg/blossom_manifest.git -b main .repo/local_manifests
repo sync -c -j32 --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh
rm -rf hardware/lineage/interfaces/sensors
source <(curl -sf https://raw.githubusercontent.com/xc112lg/scripts/refs/heads/lunaris/rbe8.sh)  >/dev/null 2>&1
. build/envsetup.sh
#export WITH_GMS=true
export WITH_GMS=false
# export WITH_GMS_COMMS_SUITE := false
# export WITH_PIXEL_LAUNCHER := false
# export TARGET_USE_GPHOTOS := false
# export TARGET_USE_WALLPAPERS := false
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_USES_PICO_GAPPS=true
export TARGET_INCLUDE_VIA=true
export TARGET_INCLUDE_REVAMPED=true
export TARGET_INCLUDE_BCR=false
sed -i '$a -include vendor/evolution-priv/keys/keys.mk' device/xiaomi/blossom/lineage_blossom.mk
sed -i '\|vendor/extras/prebuilt/product/fonts,\$(TARGET_COPY_OUT_PRODUCT)/fonts|d' vendor/extras/evolution.mk
sed -i '/<string-array name="emoji_style_entries">/,/<\/string-array>/{/emoji_style_ios\|emoji_style_samsung\|emoji_style_swiftui\|emoji_style_facebook/d}' packages/apps/Evolver/res/values/evolution_arrays.xml

# Trim the values array (property values) — must stay in sync with entries
sed -i '/<string-array name="emoji_style_values">/,/<\/string-array>/{/<item>ios<\/item>\|<item>samsung<\/item>\|<item>swiftui<\/item>\|<item>facebook<\/item>/d}' packages/apps/Evolver/res/values/evolution_arrays.xml
sed -i '/fonts_customization_emoji_\(ios\|samsung\|swiftui\|facebook\)\.xml/d' vendor/extras/evolution.mk
#sed -i '/<item>com.android.nfc<\/item>/d' frameworks/base/core/res/res/values/policy_exempt_apps.xml
#cat frameworks/base/core/res/res/values/policy_exempt_apps.xml

lunch lineage_blossom-bp4a-user

m installclean
#m clean #once
m evolution

curl -sf https://raw.githubusercontent.com/xc112lg/blossom_evolution/refs/heads/main/upevo.sh | bash >/dev/null 2>&1
