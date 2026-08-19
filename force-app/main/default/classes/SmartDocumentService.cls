public with sharing class SmartDocumentService {

    public class DocumentRequest {

        @AuraEnabled
        public Id opportunityId;

        @AuraEnabled
        public String templateName;

        @AuraEnabled
        public Boolean saveToFiles;

        @AuraEnabled
        public Boolean sendEmail;

        @AuraEnabled
        public String recipientEmail;
    }


    public class DocumentResponse {

        @AuraEnabled
        public Id contentVersionId;

        @AuraEnabled
        public Id contentDocumentId;

        @AuraEnabled
        public String fileName;

        @AuraEnabled
        public String downloadUrl;
    }


    /*
     * Original generation method.
     *
     * This remains available so your existing
     * functionality continues to work.
     */
    @AuraEnabled
    public static DocumentResponse generateDocument(
        Id opportunityId,
        String templateDeveloperName
    ) {

        if (opportunityId == null) {

            throw new AuraHandledException(
                'Opportunity Id is required.'
            );
        }


        if (String.isBlank(templateDeveloperName)) {

            throw new AuraHandledException(
                'Document template is required.'
            );
        }


        Document_Template__mdt template;


        try {

            template = [
                SELECT
                    DeveloperName,
                    Template_Name__c,
                    Visualforce_Page__c,
                    Document_Type__c,
                    Active__c,
                    Description__c
                FROM Document_Template__mdt
                WHERE DeveloperName =
                    :templateDeveloperName
                AND Active__c = true
                LIMIT 1
            ];

        } catch (Exception e) {

            throw new AuraHandledException(
                'Selected document template is not available.'
            );
        }


        Opportunity opportunity = [
            SELECT
                Id,
                Name
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];


        PageReference pageRef;


        if (
            template.Visualforce_Page__c ==
            'ProposalPDF'
        ) {

            pageRef =
                Page.ProposalPDF;

        } else {

            throw new AuraHandledException(
                'Unsupported Visualforce template.'
            );
        }


        pageRef.getParameters().put(
            'id',
            opportunityId
        );


        pageRef.getParameters().put(
            'template',
            templateDeveloperName
        );


        Blob pdfBlob;


        if (Test.isRunningTest()) {

            pdfBlob =
                Blob.valueOf(
                    'Test Proposal PDF'
                );

        } else {

            pdfBlob =
                pageRef.getContentAsPDF();
        }


        String safeName =
            sanitizeFileName(
                opportunity.Name
            );


        String fileName =
            safeName +
            ' - ' +
            sanitizeFileName(
                template.Template_Name__c
            ) +
            '.pdf';


        ContentVersion version =
            new ContentVersion();


        version.Title =
            safeName +
            ' - ' +
            sanitizeFileName(
                template.Template_Name__c
            );


        version.PathOnClient =
            fileName;


        version.VersionData =
            pdfBlob;


        version.FirstPublishLocationId =
            opportunityId;


        insert version;


        version = [
            SELECT
                Id,
                ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];


        DocumentResponse response =
            new DocumentResponse();


        response.contentVersionId =
            version.Id;


        response.contentDocumentId =
            version.ContentDocumentId;


        response.fileName =
            fileName;


        response.downloadUrl =
            '/sfc/servlet.shepherd/version/download/' +
            version.Id;


        return response;
    }


    /*
     * Generates a document using a saved
     * Document Draft.
     *
     * The Visualforce page receives draftId
     * so it can display the user's edited values.
     */
    @AuraEnabled
    public static DocumentResponse generateFromDraft(
        Id draftId
    ) {

        if (draftId == null) {

            throw new AuraHandledException(
                'Document Draft Id is required.'
            );
        }


        Document_Draft__c draft = [
            SELECT
                Id,
                Opportunity__c,
                Template_Developer_Name__c
            FROM Document_Draft__c
            WHERE Id = :draftId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];


        if (
            draft.Opportunity__c == null
        ) {

            throw new AuraHandledException(
                'The document draft is not linked to an Opportunity.'
            );
        }


        if (
            String.isBlank(
                draft.Template_Developer_Name__c
            )
        ) {

            throw new AuraHandledException(
                'The document draft does not have a template.'
            );
        }


        Document_Template__mdt template = [
            SELECT
                DeveloperName,
                Template_Name__c,
                Visualforce_Page__c,
                Active__c
            FROM Document_Template__mdt
            WHERE DeveloperName =
                :draft.Template_Developer_Name__c
            AND Active__c = true
            LIMIT 1
        ];


        if (
            template.Visualforce_Page__c !=
            'ProposalPDF'
        ) {

            throw new AuraHandledException(
                'Unsupported Visualforce template.'
            );
        }


        Opportunity opportunity = [
            SELECT
                Id,
                Name
            FROM Opportunity
            WHERE Id = :draft.Opportunity__c
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];


        PageReference pageRef =
            Page.ProposalPDF;


        pageRef.getParameters().put(
            'id',
            draft.Opportunity__c
        );


        pageRef.getParameters().put(
            'draftId',
            draft.Id
        );


        pageRef.getParameters().put(
            'template',
            draft.Template_Developer_Name__c
        );


        Blob pdfBlob;


        if (Test.isRunningTest()) {

            pdfBlob =
                Blob.valueOf(
                    'Test Proposal PDF'
                );

        } else {

            pdfBlob =
                pageRef.getContentAsPDF();
        }


        String safeName =
            sanitizeFileName(
                opportunity.Name
            );


        String fileName =
            safeName +
            ' - ' +
            sanitizeFileName(
                template.Template_Name__c
            ) +
            '.pdf';


        ContentVersion version =
            new ContentVersion();


        version.Title =
            safeName +
            ' - ' +
            sanitizeFileName(
                template.Template_Name__c
            );


        version.PathOnClient =
            fileName;


        version.VersionData =
            pdfBlob;


        version.FirstPublishLocationId =
            draft.Opportunity__c;


        insert version;


        version = [
            SELECT
                Id,
                ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];


        draft.Status__c =
            'Generated';


        update draft;


        DocumentResponse response =
            new DocumentResponse();


        response.contentVersionId =
            version.Id;


        response.contentDocumentId =
            version.ContentDocumentId;


        response.fileName =
            fileName;


        response.downloadUrl =
            '/sfc/servlet.shepherd/version/download/' +
            version.Id;


        return response;
    }


    /*
     * Removes unsafe characters from generated
     * file names.
     */
    private static String sanitizeFileName(
        String value
    ) {

        if (String.isBlank(value)) {

            return 'Document';
        }


        return value
            .replaceAll(
                '[^a-zA-Z0-9\\-_ ]',
                ''
            )
            .trim();
    }
}