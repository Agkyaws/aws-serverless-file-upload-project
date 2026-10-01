import os
import json
import urllib.parse
import boto3
from datetime import datetime

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

RAW_BUCKET = os.environ.get("RAW_BUCKET")
PROCESSED_BUCKET = os.environ.get("PROCESSED_BUCKET")
TABLE_NAME = os.environ.get("TABLE_NAME")

table = dynamodb.Table(TABLE_NAME)


def handler(event, context):
    for record in event.get("Records", []):
        s3_info = record["s3"]
        bucket_name = s3_info["bucket"]["name"]
        object_key = urllib.parse.unquote_plus(s3_info["object"]["key"])

        if bucket_name != RAW_BUCKET:
            continue

        tmp_path = f"/tmp/{object_key.split('/')[-1]}"
        s3.download_file(bucket_name, object_key, tmp_path)

        processed_key = f"processed/{object_key.split('/')[-1]}"
        s3.upload_file(tmp_path, PROCESSED_BUCKET, processed_key)

        head = s3.head_object(Bucket=bucket_name, Key=object_key)
        size = head["ContentLength"]
        content_type = head.get("ContentType", "application/octet-stream")

        file_id = object_key.split("/")[-1]

        now_iso = datetime.utcnow().isoformat() + "Z"

        table.put_item(
            Item={
                "fileId": file_id,
                "rawBucket": bucket_name,
                "rawKey": object_key,
                "processedBucket": PROCESSED_BUCKET,
                "processedKey": processed_key,
                "size": size,
                "contentType": content_type,
                "status": "PROCESSED",
                "processedAt": now_iso,
            }
        )

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "OK"}),
    }