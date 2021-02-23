import json
import boto3
import os
import logging

log = logging.getLogger(__name__)
cp = boto3.client('codepipeline')

def lambda_handler(event, context):
    job_id = event['CodePipeline.job']['id']
    job_data = event['CodePipeline.job']['data']
    params = get_user_params(job_data)
    webhook = get_webhook_trigger(params['pipeline_name'], job_id)
    print('triggered webhook: ', webhook)
    return webhook

def get_user_params(job_data):
    try:
        user_parameters = job_data['actionConfiguration']['configuration']['UserParameters']
        decoded_parameters = json.loads(user_parameters)
    except Exception as e:
        log.error("UserParameters could not be decoded from JSON configuration")
    return decoded_parameters

def get_webhook_trigger(name, job_id)
    pipeline_executions = cp.list_pipeline_executions(pipelineName=name)['pipelineExecutionSummaries']
    current_run = next(filter(lambda x: x.pipelineExecutionId == job_id, pipeline_executions), None)
    if current_run['status'] == 'InProgress' and execution['triggerType'] == 'Webhook':
        triggered_webhook = execution['triggerDetail']
    return triggered_webhook

# def get_repo_name(webhook_arn):
#     repo_name = split(webhook_arn, ":")[-1]
def put_job_success(job_id, repo_name):
    cp.put_job_success_result(
        jobId=job_id,
        outputVariables={
            'RepoName': repo_name
        }
    )









