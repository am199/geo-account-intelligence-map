public with sharing class SmartDocumentEmailService {

    @AuraEnabled
    public static void sendDocument(
        Id contentVersionId,
        Id opportunityId,
        String recipientEmail
    ) {

        if (contentVersionId == null) {
            throw new AuraHandledException(
                'Document is required.'
            );
        }

        if (String.isBlank(recipientEmail)) {
            throw new AuraHandledException(
                'Recipient email is required.'
            );
        }

        ContentVersion version = [
            SELECT
                Id,
                Title,
                VersionData,
                FileExtension
            FROM ContentVersion
            WHERE Id = :contentVersionId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        Opportunity opportunity = [
            SELECT
                Id,
                Name,
                Account.Name
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        Messaging.EmailFileAttachment attachment =
            new Messaging.EmailFileAttachment();

        attachment.setFileName(
            version.Title +
            '.' +
            version.FileExtension
        );

        attachment.setBody(
            version.VersionData
        );

        attachment.setContentType(
            'application/pdf'
        );

        Messaging.SingleEmailMessage email =
            new Messaging.SingleEmailMessage();

        email.setToAddresses(
            new List<String>{
                recipientEmail
            }
        );

        email.setSubject(
            'Proposal - ' +
            opportunity.Name
        );

        email.setPlainTextBody(
            'Hello,\n\n' +
            'Please find attached the proposal for ' +
            opportunity.Name +
            '.\n\n' +
            'Regards,\n' +
            'Sales Team'
        );

        email.setFileAttachments(
            new List<Messaging.EmailFileAttachment>{
                attachment
            }
        );

        Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{
                email
            }
        );
    }
}