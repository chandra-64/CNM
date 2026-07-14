import json
import os
import boto3
from boto3.dynamodb.conditions import Key
from prometheus_client import CollectorRegistry, Counter, push_to_gateway

# 1. Initialize the DynamoDB client
options = {}
endpoint_url = os.environ.get("AWS_ENDPOINT_URL")

if endpoint_url:
    if "localhost" in endpoint_url:
        endpoint_url = endpoint_url.replace("localhost", "host.docker.internal")
    options["endpoint_url"] = endpoint_url

dynamodb = boto3.resource("dynamodb", region_name="us-east-1", **options)
table = dynamodb.Table(os.environ.get("DYNAMODB_TABLE", "BookInventory"))

def handler(event, context):
    http_method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    
    # Setup Prometheus Metrics Tracking
    registry = CollectorRegistry()
    request_counter = Counter(
        'api_requests_total', 
        'Total number of API invocations handled by Lambda', 
        ['method'], 
        registry=registry
    )
    
    try:
        if http_method == "POST":
            request_counter.labels(method="POST").inc()
            body = json.loads(event.get("body", "{}"))
            table.put_item(Item=body)
            response_payload = response(201, {"message": "Book added successfully", "book": body})
            
        elif http_method == "GET":
            request_counter.labels(method="GET").inc()
            path_params = event.get("pathParameters") or {}
            book_id = path_params.get("proxy", "").split("/")[-1]
            
            if not book_id:
                raw_path = event.get("rawPath", event.get("path", ""))
                if raw_path and raw_path.rstrip("/") != "/books":
                    book_id = raw_path.split("/")[-1]
            
            if not book_id:
                response_payload = response(400, {"error": "Missing book_id"})
            else:
                res = table.get_item(Key={"book_id": book_id})
                if "Item" in res:
                    response_payload = response(200, res["Item"])
                else:
                    response_payload = response(404, {"error": "Book not found"})
            
        elif http_method == "DELETE":
            request_counter.labels(method="DELETE").inc()
            path_params = event.get("pathParameters") or {}
            book_id = path_params.get("proxy", "").split("/")[-1]
            
            if not book_id:
                raw_path = event.get("rawPath", event.get("path", ""))
                if raw_path and raw_path.rstrip("/") != "/books":
                    book_id = raw_path.split("/")[-1]
            
            if not book_id:
                response_payload = response(400, {"error": "Missing book_id"})
            else:
                table.delete_item(Key={"book_id": book_id})
                response_payload = response(200, {"message": f"Book with id {book_id} deleted successfully"})
            
        else:
            response_payload = response(405, {"error": f"Method {http_method} not allowed"})
            
    except Exception as e:
        response_payload = response(500, {"error": str(e)})
        
    try:
        push_to_gateway('host.docker.internal:9091', job='book_api_service', registry=registry)
    except Exception as telemetry_error:
        print(f"Telemetry submission bypassed: {str(telemetry_error)}")
        
    return response_payload

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }