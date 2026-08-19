public with sharing class DocumentDraftService {

    public class DraftResponse {

        @AuraEnabled
        public Id draftId;

        @AuraEnabled
        public Id opportunityId;

        @AuraEnabled
        public String templateDeveloperName;

        @AuraEnabled
        public Decimal proposalAmount;

        @AuraEnabled
        public Date validUntil;

        @AuraEnabled
        public String executiveSummary;

        @AuraEnabled
        public String paymentTerms;

        @AuraEnabled
        public String additionalNotes;

        @AuraEnabled
        public String status;
    }


    /*
     * Creates a new document draft using the
     * Opportunity's current values as defaults.
     */
    @AuraEnabled
    public static DraftResponse createDraft(
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


        Opportunity opportunity = [
            SELECT
                Id,
                Name,
                Amount,
                CloseDate
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];


        Document_Draft__c draft =
            new Document_Draft__c();

        draft.Opportunity__c =
            opportunity.Id;

        draft.Template_Developer_Name__c =
            templateDeveloperName;

        draft.Proposal_Amount__c =
            opportunity.Amount;

        draft.Valid_Until__c =
            opportunity.CloseDate;

        draft.Executive_Summary__c =
            'We are pleased to present this proposal to ' +
            opportunity.Name + '.';

        draft.Payment_Terms__c =
            'Payment terms to be agreed upon by both parties.';

        draft.Additional_Notes__c =
            '';

        draft.Status__c =
            'Draft';


        insert draft;


        return getDraftResponse(
            draft.Id
        );
    }


    /*
     * Retrieves an existing draft.
     */
    @AuraEnabled
    public static DraftResponse getDraft(
        Id draftId
    ) {

        if (draftId == null) {

            throw new AuraHandledException(
                'Draft Id is required.'
            );
        }


        return getDraftResponse(
            draftId
        );
    }


    /*
     * Saves the user's edited document values.
     */
    @AuraEnabled
    public static DraftResponse updateDraft(
        Id draftId,
        Decimal proposalAmount,
        Date validUntil,
        String executiveSummary,
        String paymentTerms,
        String additionalNotes
    ) {

        if (draftId == null) {

            throw new AuraHandledException(
                'Draft Id is required.'
            );
        }


        Document_Draft__c draft = [
            SELECT
                Id,
                Proposal_Amount__c,
                Valid_Until__c,
                Executive_Summary__c,
                Payment_Terms__c,
                Additional_Notes__c,
                Status__c
            FROM Document_Draft__c
            WHERE Id = :draftId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];


        draft.Proposal_Amount__c =
            proposalAmount;

        draft.Valid_Until__c =
            validUntil;

        draft.Executive_Summary__c =
            executiveSummary;

        draft.Payment_Terms__c =
            paymentTerms;

        draft.Additional_Notes__c =
            additionalNotes;

        draft.Status__c =
            'Draft';


        update draft;


        return getDraftResponse(
            draft.Id
        );
    }


    /*
     * Marks a draft as generated.
     */
    @AuraEnabled
    public static void markAsGenerated(
        Id draftId
    ) {

        if (draftId == null) {

            throw new AuraHandledException(
                'Draft Id is required.'
            );
        }


        Document_Draft__c draft = [
            SELECT
                Id,
                Status__c
            FROM Document_Draft__c
            WHERE Id = :draftId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];


        draft.Status__c =
            'Generated';


        update draft;
    }


    /*
     * Internal helper.
     */
    private static DraftResponse getDraftResponse(
        Id draftId
    ) {

        Document_Draft__c draft = [
            SELECT
                Id,
                Opportunity__c,
                Template_Developer_Name__c,
                Proposal_Amount__c,
                Valid_Until__c,
                Executive_Summary__c,
                Payment_Terms__c,
                Additional_Notes__c,
                Status__c
            FROM Document_Draft__c
            WHERE Id = :draftId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];


        DraftResponse response =
            new DraftResponse();


        response.draftId =
            draft.Id;

        response.opportunityId =
            draft.Opportunity__c;

        response.templateDeveloperName =
            draft.Template_Developer_Name__c;

        response.proposalAmount =
            draft.Proposal_Amount__c;

        response.validUntil =
            draft.Valid_Until__c;

        response.executiveSummary =
            draft.Executive_Summary__c;

        response.paymentTerms =
            draft.Payment_Terms__c;

        response.additionalNotes =
            draft.Additional_Notes__c;

        response.status =
            draft.Status__c;


        return response;
    }
}