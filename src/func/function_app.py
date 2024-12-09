import logging
import time
from datetime import datetime
import azure.functions as func
import json
app = func.FunctionApp()
@app.route(route="echo", auth_level=func.AuthLevel.ANONYMOUS)
async def echo(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')
    
    # Record the time request arrived
    request_time = datetime.utcnow()
    
    # Simulate processing time
    time.sleep(1)
    
    # Get the name from query parameters or request body
    name = req.params.get('name')
    if not name:
        try:
            req_body = req.get_json()
        except ValueError:
            req_body = None
        name = req_body.get('name') if req_body else None

    # Record the time for the response
    response_time = datetime.utcnow()
    elapsed_time_ms = int((response_time - request_time).total_seconds() * 1000)
    
    # Prepare the JSON response
    response_data = {
        "request_time": request_time.isoformat() + "Z",
        "elapsed_time_ms": elapsed_time_ms,
        "name": name if name else None
    }
    
    return func.HttpResponse(
        json.dumps(response_data),
        status_code=200,
        mimetype="application/json"
    )
