public with sharing class PlatformEventPublisher {
    public static void importProgress(String importId, String status, Integer processedRows, Integer totalRows, String message) {
        Import_Progress__e eventRecord = new Import_Progress__e(
            Import_Id__c = importId,
            Status__c = status,
            Processed_Rows__c = processedRows,
            Total_Rows__c = totalRows,
            Message__c = message
        );
        EventBus.publish(eventRecord);
    }

    public static void importError(String importId, Integer rowNumber, String objectApiName, String errorMessage, String rawPayload) {
        Import_Error__e eventRecord = new Import_Error__e(
            Import_Id__c = importId,
            Row_Number__c = rowNumber,
            Object_Api_Name__c = objectApiName,
            Error_Message__c = errorMessage,
            Raw_Payload__c = rawPayload
        );
        EventBus.publish(eventRecord);
    }

    public static void mergeAudit(String mergeId, String objectApiName, Id masterRecordId, List<Id> mergedRecordIds, String summary) {
        Merge_Audit__e eventRecord = new Merge_Audit__e(
            Merge_Id__c = mergeId,
            Object_Api_Name__c = objectApiName,
            Master_Record_Id__c = String.valueOf(masterRecordId),
            Merged_Record_Ids__c = joinedIds(mergedRecordIds),
            Summary__c = summary
        );
        EventBus.publish(eventRecord);
    }

    private static String joinedIds(List<Id> ids) {
        List<String> values = new List<String>();
        if (ids != null) {
            for (Id recordId : ids) {
                values.add(String.valueOf(recordId));
            }
        }
        return String.join(values, ',');
    }
}