public with sharing class SmartDocumentHistoryService {

    public class DocumentVersion {
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
        @AuraEnabled public String downloadUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<DocumentVersion> getHistory(
        Id opportunityId
    ) {

        List<DocumentVersion> results =
            new List<DocumentVersion>();

        if (opportunityId == null) {
            return results;
        }

        List<ContentDocumentLink> links = [
            SELECT
                ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
            WITH SECURITY_ENFORCED
        ];

        Set<Id> documentIds =
            new Set<Id>();

        for (ContentDocumentLink link : links) {
            documentIds.add(
                link.ContentDocumentId
            );
        }

        if (documentIds.isEmpty()) {
            return results;
        }

        List<ContentVersion> versions = [
            SELECT
                Id,
                ContentDocumentId,
                Title,
                FileExtension,
                CreatedDate,
                CreatedBy.Name
            FROM ContentVersion
            WHERE ContentDocumentId IN :documentIds
            AND FileExtension = 'pdf'
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];

        for (ContentVersion version : versions) {

            DocumentVersion item =
                new DocumentVersion();

            item.contentVersionId =
                version.Id;

            item.contentDocumentId =
                version.ContentDocumentId;

            item.title =
                version.Title;

            item.fileType =
                version.FileExtension;

            item.createdDate =
                version.CreatedDate;

            item.createdByName =
                version.CreatedBy.Name;

            item.downloadUrl =
                '/sfc/servlet.shepherd/version/download/' +
                version.Id;

            results.add(item);
        }

        return results;
    }
    @AuraEnabled
public static void deleteDocument(Id contentDocumentId) {

    if (contentDocumentId == null) {
        throw new AuraHandledException(
            'Document Id is required.'
        );
    }

    try {

        ContentDocument document = [
            SELECT Id
            FROM ContentDocument
            WHERE Id = :contentDocumentId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        delete document;

    } catch (QueryException e) {

        throw new AuraHandledException(
            'Document was not found.'
        );

    } catch (DmlException e) {

        throw new AuraHandledException(
            'Unable to delete the document. Please check your permissions.'
        );
    }
}
}