import os
import json
import uuid
import boto3

s3 = boto3.client("s3")

BUCKET_NAME = os.environ.get("BUCKET_NAME")
URL_EXPIRY = int(os.environ.get("URL_EXPIRY", "900"))


def handler(event, context):
    try:
        body = {}
        if event.get("body"):
            body = json.loads(event["body"])
    except Exception:
        body = {}

    content_type = body.get("contentType", "application/octet-stream")

    file_id = str(uuid.uuid4())
    object_key = f"uploads/{file_id}"

    url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": BUCKET_NAME,
            "Key": object_key,
            "ContentType": content_type,
        },
        ExpiresIn=URL_EXPIRY,
    )

    response_body = {
        "fileId": file_id,
        "uploadUrl": url,
        "bucket": BUCKET_NAME,
        "key": object_key,
        "expiresIn": URL_EXPIRY,
    }

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(response_body),
    }