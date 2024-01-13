import http.client
import os
import ssl
import json
from typing import List, Dict, Union, Any, Optional

KUBE_API_ENDPOINT = os.getenv("KUBE_API_ENDPOINT")


def yaml_to_json(yaml_str: str) -> List[Dict[str, Union[str, List[str]]]]:
    """
    Convert YAML string to JSON object.
    """
    result, current_dict = [], {}
    is_groups = False

    for line in yaml_str.split("\n"):
        line = line.strip()

        if line in ("-", "- groups:"):
            if current_dict:
                result.append(current_dict)
            current_dict = {}
            is_groups = line == "- groups:"
            if is_groups:
                current_dict["groups"] = []
            continue

        if line.startswith("groups:"):
            current_dict["groups"] = []
            is_groups = True
        elif line.startswith("- ") and is_groups:
            current_dict["groups"].append(line[2:])
            continue

        if ": " in line:
            key, value = line.split(": ", 1)
            current_dict[key] = value

    if current_dict:
        result.append(current_dict)

    return result


def json_to_yaml(json_obj: List[Dict[str, Union[str, List[str]]]]) -> str:
    """
    Convert JSON object to YAML string.
    """
    yaml_str = ""
    for item in json_obj:
        yaml_str += "-\n"
        for key in ["rolearn", "username", "groups"]:
            value = item.get(key)
            if key == "groups" and value:
                yaml_str += "  groups:\n"
                for v in value:
                    yaml_str += f"    - {v}\n"
            elif value:
                yaml_str += f"  {key}: {value}\n"
    return yaml_str.strip()


def make_request(
    method: str,
    url: str,
    host: str,
    token: str,
    context: Optional[ssl.SSLContext] = None,
    payload: Optional[Dict[str, Any]] = None,
) -> http.client.HTTPResponse:
    """
    Make an HTTP request.
    """
    try:
        conn = (
            http.client.HTTPSConnection(host, context=context)
            if context
            else http.client.HTTPConnection(host)
        )
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        body = json.dumps(payload) if payload else None
        conn.request(method, url, body=body, headers=headers)
        return conn.getresponse()
    except Exception as e:
        print(f"Error making HTTP request: {e}")
        raise


def update_config_map(
    kube_api_endpoint: str, token: str, payload: Dict[str, Any]
) -> Dict[str, Union[str, int]]:
    """
    Update the Kubernetes ConfigMap.
    """
    try:
        context = (
            ssl._create_unverified_context()
            if "https://" in kube_api_endpoint
            else None
        )
        host = kube_api_endpoint.split("://")[-1]
        data = {
            "apiVersion": "v1",
            "data": payload,
            "kind": "ConfigMap",
            "metadata": {"name": "aws-auth", "namespace": "kube-system"},
        }
        response = make_request(
            "PUT",
            "/api/v1/namespaces/kube-system/configmaps/aws-auth",
            host,
            token,
            context,
            data,
        )
        response_data = response.read().decode()

        if response.status in [200, 204]:
            return {"message": "ConfigMap updated successfully"}
        else:
            return {
                "error": "Failed to update ConfigMap",
                "status_code": response.status,
                "response": response_data,
            }
    except Exception as e:
        return {"error": str(e)}


def process_config_map(event: Dict[str, Any]) -> Dict[str, Union[str, int]]:
    """
    Process the ConfigMap update event.
    """
    try:
        token = event["token"]
        role_arn = event["role_arn"]

        context = (
            ssl._create_unverified_context()
            if "https://" in KUBE_API_ENDPOINT
            else None
        )
        host = KUBE_API_ENDPOINT.split("://")[-1]
        response = make_request(
            "GET",
            "/api/v1/namespaces/kube-system/configmaps/aws-auth",
            host,
            token,
            context,
        )

        if response.status != 200:
            return {"error": "Failed to get configmap", "status_code": response.status}

        json_data = json.loads(response.read())
        map_roles = yaml_to_json(json_data["data"]["mapRoles"])
        new_entry = {
            "groups": ["system:bootstrappers", "system:nodes"],
            "rolearn": role_arn,
            "username": "system:node:{{EC2PrivateDNSName}}",
        }

        if new_entry in map_roles:
            return {"message": "Entry already exists in mapRoles"}

        map_roles.append(new_entry)
        new_map_roles_str = json_to_yaml(map_roles)
        payload = json_data["data"]
        payload["mapRoles"] = new_map_roles_str
        return update_config_map(KUBE_API_ENDPOINT, token, payload)
    except Exception as e:
        return {"error": str(e)}


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Union[str, int]]:
    """
    AWS Lambda handler function.
    """
    return process_config_map(event)
