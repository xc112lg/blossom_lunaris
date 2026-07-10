# Check and load environment variables from .env
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
    echo "✓ Loaded .env from current directory"
elif [ -f ../.env ]; then
    export $(cat ../.env | grep -v '#' | xargs)
    echo "✓ Loaded .env from parent directory"
else
    echo "⚠ .env file not found"
fi

if ls out/target/product/*/*.zip >/dev/null 2>&1; then

rm -rf blossom_evolution
git clone https://$GH_TOKEN@github.com//xc112lg/blossom_evolution

#cd -
#rm -rf blossom_lunaris/*.img blossom_lunaris/*.zip blossom_lunaris/*.tar
#cp out/target/product/*/recovery.img blossom_lunaris
cp out/target/product/*/*.zip blossom_evolution/
# echo "test" > blossom_lunaris/dummy.txt

# Create the zip
# zip -q blossom_lunaris/test.zip blossom_lunaris/dummy.txt

# Check size
# ls -lh blossom_lunaris/test.zip
cp out/target/product/*/*.tar blossom_evolution
cd blossom_evolution
chmod +x multi_upload3.sh
./multi_upload3.sh > /dev/null
else
    exit 1
fi
