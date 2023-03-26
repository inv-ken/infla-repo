import sys
def handler(event, context):
    return {'statusCode': 200,
            'body':'Hello1 from AWS Lambda using Python' + sys.version + '!'  
    }