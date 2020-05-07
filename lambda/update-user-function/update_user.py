import json
import urllib.parse
import boto3
from enum import Enum 

print('Loading function')

dynamodb = boto3.client('dynamodb')

class UserEventType(Enum):
    USER_REGISTRATION = 'ss'
    EMAIL_VERIFICATION_REQUESTED = 'svr'
    EMAIL_VERIFIED = 'sv'

class UserStatus(Enum):
    NEW = 'New'
    PENDING_EMAIL_VERIFICATIION = 'Pending'
    ACTIVE = 'Active'

def handler(event, context):
    event_type = event['detail']['data']['type']
    user_id = event['detail']['data']['user_name']
    user_status = ''
    
    if event_type == UserEventType.USER_REGISTRATION.value:
        user_status = UserStatus.NEW.value
    elif event_type == UserEventType.EMAIL_VERIFICATION_REQUESTED.value:
        user_status = UserStatus.PENDING_EMAIL_VERIFICATIION.value
    elif event_type == UserEventType.EMAIL_VERIFIED.value:
        user_status = UserStatus.ACTIVE.value
    else:
        return {'error': 'invalid event type'}

    dynamodb.update_item(
        TableName='users-table',
        Key={'user_id':{'S':user_id}},
        AttributeUpdates={'status':{'Value':{'S':user_status}}}
        )
    
    return {'message': 'OK'}