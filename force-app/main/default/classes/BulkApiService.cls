public with sharing class BulkApiService {
    public class BulkJobRequest {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String operation;
        @AuraEnabled public String csvBody;
    }

    public class BulkJobResponse {
        @AuraEnabled public String jobId;
        @AuraEnabled public String state;
        @AuraEnabled public String message;
    }

    public static BulkJobResponse createIngestJob(BulkJobRequest request) {
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint('callout:Salesforce/services/data/v61.0/jobs/ingest');
        httpRequest.setMethod('POST');
        httpRequest.setHeader('Content-Type', 'application/json');
        httpRequest.setBody(JSON.serialize(new Map<String, Object>{
            'object' => request.objectApiName,
            'operation' => String.isBlank(request.operation) ? 'insert' : request.operation,
            'contentType' => 'CSV',
            'lineEnding' => 'LF'
        }));

        HttpResponse response = new Http().send(httpRequest);
        BulkJobResponse result = new BulkJobResponse();
        result.message = response.getBody();
        if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.jobId = (String) payload.get('id');
            result.state = (String) payload.get('state');
        } else {
            result.state = 'Failed';
        }
        return result;
    }

    public static BulkJobResponse uploadJobData(String jobId, String csvBody) {
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint('callout:Salesforce/services/data/v61.0/jobs/ingest/' + jobId + '/batches');
        httpRequest.setMethod('PUT');
        httpRequest.setHeader('Content-Type', 'text/csv');
        httpRequest.setBody(csvBody);

        HttpResponse response = new Http().send(httpRequest);
        BulkJobResponse result = new BulkJobResponse();
        result.jobId = jobId;
        result.state = response.getStatusCode() >= 200 && response.getStatusCode() < 300 ? 'UploadComplete' : 'Failed';
        result.message = response.getBody();
        return result;
    }

    public static BulkJobResponse closeJob(String jobId) {
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint('callout:Salesforce/services/data/v61.0/jobs/ingest/' + jobId);
        httpRequest.setMethod('PATCH');
        httpRequest.setHeader('Content-Type', 'application/json');
        httpRequest.setBody('{"state":"UploadComplete"}');

        HttpResponse response = new Http().send(httpRequest);
        BulkJobResponse result = new BulkJobResponse();
        result.jobId = jobId;
        result.state = response.getStatusCode() >= 200 && response.getStatusCode() < 300 ? 'UploadComplete' : 'Failed';
        result.message = response.getBody();
        return result;
    }
}