set -e

rm -f lambda_presign.zip lambda_processor.zip

cd lambda
zip -r ../lambda_presign.zip presign.py
zip -r ../lambda_processor.zip processor.py
cd -