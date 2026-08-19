public with sharing class MergeExecutionService {
    public class MergeRequest {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public Id masterRecordId;
        @AuraEnabled public List<Id> duplicateRecordIds;
    }

    public class MergeResultDto {
        @AuraEnabled public String mergeId;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=false)
    public static MergeResultDto mergeRecords(MergeRequest request) {
        if (request == null || request.masterRecordId == null || request.duplicateRecordIds == null || request.duplicateRecordIds.isEmpty()) {
            throw new AuraHandledException('Master record and duplicate record ids are required.');
        }
        if (request.duplicateRecordIds.size() > 2) {
            throw new AuraHandledException('Salesforce merge supports up to two duplicate records per operation.');
        }

        MergeResultDto result = new MergeResultDto();
        result.mergeId = 'MRG-' + String.valueOf(DateTime.now().getTime());

        if (request.objectApiName == 'Account') {
            Account master = [SELECT Id, Name FROM Account WHERE Id = :request.masterRecordId LIMIT 1];
            List<Account> duplicates = [SELECT Id, Name FROM Account WHERE Id IN :request.duplicateRecordIds];
            Database.MergeResult[] mergeResults = Database.merge(master, duplicates, false);
            result.success = allMergeResultsSucceeded(mergeResults);
        } else if (request.objectApiName == 'Contact') {
            Contact master = [SELECT Id, FirstName, LastName FROM Contact WHERE Id = :request.masterRecordId LIMIT 1];
            List<Contact> duplicates = [SELECT Id, FirstName, LastName FROM Contact WHERE Id IN :request.duplicateRecordIds];
            Database.MergeResult[] mergeResults = Database.merge(master, duplicates, false);
            result.success = allMergeResultsSucceeded(mergeResults);
        } else if (request.objectApiName == 'Lead') {
            Lead master = [SELECT Id, FirstName, LastName, Company FROM Lead WHERE Id = :request.masterRecordId LIMIT 1];
            List<Lead> duplicates = [SELECT Id, FirstName, LastName, Company FROM Lead WHERE Id IN :request.duplicateRecordIds];
            Database.MergeResult[] mergeResults = Database.merge(master, duplicates, false);
            result.success = allMergeResultsSucceeded(mergeResults);
        } else {
            throw new AuraHandledException('Merge is supported for Account, Contact, and Lead.');
        }

        result.message = result.success ? 'Merge completed.' : 'Merge failed. Review validation rules and sharing access.';
        PlatformEventPublisher.mergeAudit(result.mergeId, request.objectApiName, request.masterRecordId, request.duplicateRecordIds, result.message);
        createFeedAudit(request, result);
        return result;
    }

    private static Boolean allMergeResultsSucceeded(Database.MergeResult[] results) {
        for (Database.MergeResult item : results) {
            if (!item.isSuccess()) {
                return false;
            }
        }
        return true;
    }

    private static void createFeedAudit(MergeRequest request, MergeResultDto result) {
        try {
            insert new FeedItem(
                ParentId = request.masterRecordId,
                Body = 'Data Quality Intelligence Cloud merge ' + result.mergeId + ': ' + result.message,
                Type = 'TextPost'
            );
        } catch (Exception ignored) {
            // Feed tracking may be disabled in some orgs; Platform Event audit still records the merge.
        }
    }
}