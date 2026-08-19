public with sharing class LocationAccountOpp {

    /*
    ============================================================
    WRAPPERS
    ============================================================
    */

    public class PicklistOptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class AccountWrapper {

        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String industry;

        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;

        @AuraEnabled public String ownerName;

        @AuraEnabled public Decimal pipelineAmount;

        @AuraEnabled public String stage;

        @AuraEnabled public String primaryContact;
    }

    public class VersionHistoryWrapper {

        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public Datetime createdDate;
    }


    /*
    ============================================================
    DYNAMIC PICKLIST VALUES
    ============================================================
    */

    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionWrapper> getPicklistValues(
        String objectApiName,
        String fieldApiName
    ) {

        List<PicklistOptionWrapper> options =
            new List<PicklistOptionWrapper>();

        Schema.SObjectType objType =
            Schema.getGlobalDescribe().get(objectApiName);

        if(objType == null) {
            return options;
        }

        Schema.DescribeSObjectResult objDescribe =
            objType.getDescribe();

        Schema.DescribeFieldResult fieldDescribe =
            objDescribe.fields.getMap()
            .get(fieldApiName)
            .getDescribe();

        for(Schema.PicklistEntry entry :
            fieldDescribe.getPicklistValues()) {

            if(entry.isActive()) {

                PicklistOptionWrapper option =
                    new PicklistOptionWrapper();

                option.label = entry.getLabel();
                option.value = entry.getValue();

                options.add(option);
            }
        }

        return options;
    }


    /*
    ============================================================
    GEOLOCATION ACCOUNT QUERY
    ============================================================
    */

    @AuraEnabled(cacheable=true)
    public static List<AccountWrapper> getNearbyAccounts(

        String industryFilter,
        String stageFilter,

        Decimal latitude,
        Decimal longitude,

        Integer radiusKm
    ) {

        List<AccountWrapper> response =
            new List<AccountWrapper>();

        String query =
            'SELECT Id, ' +
            'Name, ' +
            'Industry, ' +
            'BillingLatitude, ' +
            'BillingLongitude, ' +
            'Owner.Name, ' +

            '(SELECT Id, Name, StageName, Amount FROM Opportunities), ' +

            '(SELECT Id, Name, Email FROM Contacts LIMIT 1) ' +

            'FROM Account ' +

            'WHERE BillingLatitude != null ' +
            'AND BillingLongitude != null ';

        if(String.isNotBlank(industryFilter)) {

            query +=
                'AND Industry = :industryFilter ';
        }

        query +=
            'AND DISTANCE(' +
            'BillingAddress, ' +
            'GEOLOCATION(:latitude, :longitude), ' +
            '\'km\'' +
            ') < :radiusKm';

        List<Account> accounts =
            Database.query(query);

        for(Account acc : accounts) {

            Decimal pipeline = 0;
            String stage = 'No Opportunity';

            if(acc.Opportunities != null &&
               !acc.Opportunities.isEmpty()) {

                for(Opportunity opp : acc.Opportunities) {

                    pipeline +=
                        opp.Amount == null
                        ? 0
                        : opp.Amount;

                    if(
                        String.isBlank(stageFilter) ||
                        opp.StageName == stageFilter
                    ) {
                        stage = opp.StageName;
                    }
                }
            }

            AccountWrapper wrapper =
                new AccountWrapper();

            wrapper.accountId = acc.Id;
            wrapper.accountName = acc.Name;
            wrapper.industry = acc.Industry;

            wrapper.latitude = acc.BillingLatitude;
            wrapper.longitude = acc.BillingLongitude;

            wrapper.ownerName = acc.Owner.Name;

            wrapper.pipelineAmount = pipeline;

            wrapper.stage = stage;

            if(
                acc.Contacts != null &&
                !acc.Contacts.isEmpty()
            ) {
                wrapper.primaryContact =
                    acc.Contacts[0].Name;
            }

            response.add(wrapper);
        }

        return response;
    }


    /*
    ============================================================
    ACTIVE TEMPLATES
    ============================================================
    

    @AuraEnabled(cacheable=true)
    public static List<String> getActiveTemplates() {

        List<String> templates =
            new List<String>();

        for(Proposal_Template__mdt temp : [

            SELECT Template_Name__c

            FROM Proposal_Template__mdt

            WHERE Active__c = true

            ORDER BY Template_Name__c
        ]) {

            templates.add(
                temp.Template_Name__c
            );
        }

        return templates;
    }


    /*
    ============================================================
    GENERATE HTML PREVIEW
    ============================================================
    

    @AuraEnabled(cacheable=true)
    public static String generatePreview(

        Id opportunityId,
        String templateName

    ) {

        Opportunity opp = [

            SELECT Id,
                   Name,
                   Amount,
                   StageName,
                   CloseDate,

                   Account.Name,
                   Account.BillingCity,

                   (
                       SELECT Quantity,
                              TotalPrice,
                              UnitPrice,
                              PricebookEntry.Product2.Name
                       FROM OpportunityLineItems
                   )

            FROM Opportunity

            WHERE Id = :opportunityId

            LIMIT 1
        ];

        Proposal_Template__mdt templateRecord = [

            SELECT Html_Template__c

            FROM Proposal_Template__mdt

            WHERE Template_Name__c = :templateName

            LIMIT 1
        ];

        String html =
            templateRecord.Html_Template__c;

        html = html.replace(
            '{!OpportunityName}',
            opp.Name
        );

        html = html.replace(
            '{!AccountName}',
            opp.Account.Name
        );

        html = html.replace(
            '{!TotalAmount}',
            String.valueOf(opp.Amount)
        );

        html = html.replace(
            '{!StageName}',
            opp.StageName
        );

        html = html.replace(
            '{!CloseDate}',
            String.valueOf(opp.CloseDate)
        );

        /*
        ========================================
        DYNAMIC PRODUCT TABLE
        ========================================
        

        String productTable =
            '<table border=\"1\" width=\"100%\">' +

            '<tr>' +
            '<th>Product</th>' +
            '<th>Qty</th>' +
            '<th>Unit Price</th>' +
            '<th>Total</th>' +
            '</tr>';

        for(OpportunityLineItem oli :
            opp.OpportunityLineItems) {

            productTable +=

                '<tr>' +

                '<td>' +
                oli.PricebookEntry.Product2.Name +
                '</td>' +

                '<td>' +
                oli.Quantity +
                '</td>' +

                '<td>' +
                oli.UnitPrice +
                '</td>' +

                '<td>' +
                oli.TotalPrice +
                '</td>' +

                '</tr>';
        }

        productTable += '</table>';

        html = html.replace(
            '{!ProductTable}',
            productTable
        );

        return html;
    }


    /*
    ============================================================
    SAVE PDF INTO SALESFORCE FILES
    ============================================================
    */

    @AuraEnabled
    public static Id savePdf(

        Id recordId,
        String fileName,
        String base64Data

    ) {

        Blob pdfBlob =
            EncodingUtil.base64Decode(base64Data);

        ContentVersion cv =
            new ContentVersion();

        cv.Title = fileName;

        cv.PathOnClient =
            fileName + '.pdf';

        cv.VersionData = pdfBlob;

        insert cv;

        cv = [

            SELECT Id,
                   ContentDocumentId

            FROM ContentVersion

            WHERE Id = :cv.Id
        ];

        ContentDocumentLink cdl =
            new ContentDocumentLink();

        cdl.LinkedEntityId = recordId;

        cdl.ContentDocumentId =
            cv.ContentDocumentId;

        cdl.ShareType = 'V';

        cdl.Visibility = 'AllUsers';

        insert cdl;

        return cv.Id;
    }


    /*
    ============================================================
    FILE VERSION HISTORY
    ============================================================
    */

    @AuraEnabled(cacheable=true)
    public static List<VersionHistoryWrapper>
    getVersionHistory(Id recordId) {

        List<VersionHistoryWrapper> response =
            new List<VersionHistoryWrapper>();

        for(ContentDocumentLink cdl : [

            SELECT ContentDocument.Title,
                   ContentDocument.FileType,
                   ContentDocument.CreatedDate

            FROM ContentDocumentLink

            WHERE LinkedEntityId = :recordId

            ORDER BY ContentDocument.CreatedDate DESC
        ]) {

            VersionHistoryWrapper wrapper =
                new VersionHistoryWrapper();

            wrapper.title =
                cdl.ContentDocument.Title;

            wrapper.fileType =
                cdl.ContentDocument.FileType;

            wrapper.createdDate =
                cdl.ContentDocument.CreatedDate;

            response.add(wrapper);
        }

        return response;
    }


    /*
    ============================================================
    SEND EMAIL WITH PDF ATTACHMENT
    ============================================================
    */

    @AuraEnabled
    public static void sendProposalEmail(

        String recipientEmail,
        String subject,

        String body,

        String fileName,
        String base64Data

    ) {

        Blob pdfBlob =
            EncodingUtil.base64Decode(base64Data);

        Messaging.EmailFileAttachment
            attachment =
            new Messaging.EmailFileAttachment();

        attachment.setFileName(
            fileName + '.pdf'
        );

        attachment.setBody(pdfBlob);

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

        email.setSubject(subject);

        email.setPlainTextBody(body);

        email.setFileAttachments(
            new Messaging.EmailFileAttachment[] {
                attachment
            }
        );

        Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] {
                email
            }
        );
    }
}