# terraform-lambda-api-backend

This repo is a custom AWS Lambda API Terraform module where Lambda functions and AWS API Gateway endpoints can be configured. 

## How to Use

Example use of module:

```
module "api_gateway_example" {
  source = "../../"

  project_name = "ExampleProject"
  app_name     = "example-app"
  domain       = "fhtl-dev.org"
  url          = "example.fhtl-dev.org"
  api_url      = "api.example.fhtl-dev.org"
  image_tag    = "latest"
  ecr_repo_url = "<AWS Account ID>.dkr.ecr.us-west-2.amazonaws.com/example-app-repo"
  
  lambda_role_arn = "arn:aws:iam::<AWS Account ID>:role/LambdaApiRole"
  lambda_environment_variables = {
    ENV_VAR1 = "value1"
    ENV_VAR2 = "value2"
  }
  lambda_endpoint_definitions = [
    {
      path_part = "example-path"
      allowed_headers = ["Authorization", Content-Type, ...(any other headers)]

      method_definitions = [
        {
          http_method = "GET"
          timeout     = 30
          memory_size = 128
        },
        {
          http_method = "POST"
          timeout     = 30
          memory_size = 256
        },
        {
          http_method = "DELETE"
          timeout     = 30
          memory_size = 512
        }
      ]
    }
  ]
  function_policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"
  ]
}
```

## How to set up Docker For AWS Lambda Compatibility

This module uses the `aws-lambda-web-adapter` in order to allow REST apis to run as if being served serverlessly (like from an ec2 server for example). This is a necessary adapter to allow any backend code to functionally run, so it's very important to configure this correctly according to your backend's framework. Below is a DockerFile example for Flask endpoints:

```
FROM public.ecr.aws/docker/library/python:3.12.1-slim
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.3 /lambda-adapter /opt/extensions/lambda-adapter
WORKDIR /var/task
COPY app.py requirements.txt ./
RUN python -m pip install -r requirements.txt
CMD ["gunicorn", "-b=:8080", "-w=1", "app:app"]
```

And here is the example Flask python file `app.py`:

```
from flask import Flask, request, jsonify

app = Flask(__name__)

# Sample data store
data_store = ["koala"]

# GET endpoint
@app.route('/example-path', methods=['GET'])
def get_data():
    return jsonify(data_store), 200

# POST endpoint
@app.route('/example-path', methods=['POST'])
def post_data():
    data = request.json
    data_store.append(data)
    return jsonify(data), 201

# DELETE endpoint
@app.route('/example-path', methods=['DELETE'])
def delete_data():
    data = request.json
    if data in data_store:
        data_store.remove(data)
        return jsonify({"message": "Data deleted"}), 200
    return jsonify({"message": "Data not found"}), 404
```

For Flask apps, you need a requirements.txt that holds dependencies, and here is how this would look:

```
blinker==1.6.2
click==8.1.3
Flask==2.3.2
gunicorn==22.0.0
importlib-metadata==6.6.0
itsdangerous==2.1.2
Jinja2==3.1.4
MarkupSafe==2.1.2
Werkzeug==3.0.3
zipp==3.15.0
```

It's also nice to have a `.dockerignore` file and here is an example for that as well:

```
#.dockerignore
__pycache__/
.git/
.serverless/
.gitignore
.dockerignore
serverless.yml
```

More information on other backend frameworks can be found [here](https://github.com/awslabs/aws-lambda-web-adapter).

## Necessary Setup Steps for Module

In order for this module to work properly, a separate setup.tf file must be set aside in each backend repository where the [BYU OIT AWS acs module](https://github.com/byu-oit/terraform-aws-acs-info) must be called in order to have an IAM role that can authenticate with AWS in the GitHub actions workflow, and the ecr repository must be created in this setup.tf file as well, so then this way this module can correctly reference the ecr repository and the docker image that corresponds to it. If testing terraform locally, you must build the Docker image locally and push it with AWS CLI to the ecr repo. 
