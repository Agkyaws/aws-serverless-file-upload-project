# Building an Event-Driven Serverless File Processing Pipeline with AWS and Terraform

Uploading files directly from a user to the cloud is a smart way to build applications. Instead of sending large files through your application server, you can send them directly to Amazon S3. This method saves server costs and makes your system run much faster.

In this lab, we will build a complete file upload and processing system. We will use AWS Lambda, Amazon S3, Amazon DynamoDB, and Amazon API Gateway. To create all of this easily, we will use Terraform.

## How the System Works

1. **Request a URL:** The user sends a request to API Gateway (`POST /upload`).
2. **Generate a Secure Link:** A Lambda function creates a temporary, secure link (a pre-signed URL) to upload the file to an S3 bucket.
3. **Direct Upload:** The user uploads the file directly to the S3 "raw uploads" bucket using that link.
4. **Automatic Processing:** When the file arrives, S3 automatically triggers a second Lambda function.
5. **Save and Record:** This second Lambda function moves the file to a "processed" bucket and saves the file details into a DynamoDB table.

---

## Step 1: The Python Code for Lambda

We need two small Python scripts for our Lambda functions.

### 1. Generating the Pre-signed URL (`presign.py`)
This script receives the request and gives the user a secure link. The link is valid for a short time, usually 15 minutes (900 seconds).
*   The code uses the `boto3` library to talk to AWS.
*   It creates a unique ID for the file using `uuid`.
*   It returns the secure `uploadUrl` and the `fileId` to the user.

### 2. Processing the File (`processor.py`)
AWS automatically runs this script when a new file enters the first S3 bucket.
*   It downloads the file to a temporary folder (`/tmp/`).
*   It uploads the file to the new `PROCESSED_BUCKET`.
*   It finds the file size and the content type.
*   It saves all this information into the DynamoDB `TABLE_NAME` with a status of `"PROCESSED"`.

---

## Step 2: Setting up the Infrastructure with Terraform

We write the Terraform files to create the AWS resources.

### Managing Permissions (`iam.tf`)
Security is very important in the cloud. Each Lambda function needs permission to do its job, and nothing more. The `iam.tf` file creates these permissions.
*   The **presign role** is allowed to write logs and use `s3:PutObject` to create the upload links.
*   The **processor role** is allowed to read from the raw bucket, write to the processed bucket, and use `dynamodb:PutItem` to save records.

### The Main Infrastructure (`main.tf`)
The `main.tf` file is the heart of our project. It creates all the main AWS services:
*   **Two S3 Buckets:** One for raw uploads and one for processed files. Both have strict public access blocks and versioning enabled.
*   **DynamoDB Table:** A table named `${var.project_name}-file-metadata` using `PAY_PER_REQUEST` billing.
*   **Lambda Functions:** It creates both the `presign_url` and `processor` functions using Python 3.11.
*   **API Gateway:** It creates the HTTP API and the route for the `POST /upload` request.
*   **Triggers:** It links the raw S3 bucket to the processor Lambda function so it runs automatically on `s3:ObjectCreated:*` events.

### Variables and Outputs
To make our code easy to reuse, we use a `variables.tf` file to set basic settings like the `aws_region` (default is `us-east-1`) and `environment` (default is `dev`).

The `outputs.tf` file tells Terraform to print important information after it finishes building. It will show us the `api_endpoint` URL, the bucket names, and the DynamoDB table name.

---

## Step 3: Build and Deploy

Before we deploy with Terraform, we must compress our Python code into `.zip` files because AWS Lambda requires this format. We use a script named `build.sh` to do this quickly. This script removes old files, goes into the `lambda` folder, and uses the `zip` command to package `presign.py` and `processor.py`.

To deploy the whole project, run these commands in your terminal:

1. **Run the build script** to create the zip files: 
   ```bash
   ./build.sh
   ```
2. **Start Terraform:** 
   ```bash
   terraform init
   ```
3. **Check the plan:** 
   ```bash
   terraform plan
   ```
4. **Build the resources:** 
   ```bash
   terraform apply
   ```

---

## How to Test the Project

When Terraform finishes, it will print your API link. You can test it using the command line tool `curl`.

**1. Get the upload link:** 
Send a POST request to your API link. The API will answer with a long, secure `uploadUrl`.
```bash
curl -X POST https://<api-id>.execute-api.us-east-1.amazonaws.com/upload \
  -H "Content-Type: application/json" \
  -d '{"contentType": "text/plain"}'
```

**2. Upload your file:** 
Use `curl` to send a PUT request directly to that `uploadUrl`.
```bash
curl -X PUT "<uploadUrl>" \
  -H "Content-Type: text/plain" \
  --data "Hello world, event-driven serverless file processing!"
```

**3. Check the results:** 
Look inside your AWS console. You will see the file moved to your "processed" S3 bucket. Then, look at your DynamoDB table, and you will see a new record showing the file details and the time it was processed.

---

## Business Benefits

*   **Massive Cost Savings:** Because we use serverless tools like Lambda and API Gateway, the company only pays when someone actually uploads a file. If nobody uploads anything at night, the cost is zero. You do not have to pay for a server running 24/7.
*   **Unbreakable Scaling:** If your application suddenly becomes famous and 10,000 users try to upload files in one minute, a normal server would crash. Amazon S3 handles direct uploads effortlessly, meaning your system will not break under pressure.
*   **Better Website Performance:** Normally, large file uploads slow down the main application server. By using pre-signed URLs, the user’s computer sends the heavy file straight to AWS storage. This keeps the main application fast and smooth for everyone else.