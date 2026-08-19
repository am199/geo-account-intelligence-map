public with sharing class AgentInsightService {
    public class InvestigationRequest {
        @AuraEnabled public String question;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String objectApiName;
    }

    public class InvestigationResponse {
        @AuraEnabled public String summary;
        @AuraEnabled public List<String> groundingFacts;
        @AuraEnabled public List<String> recommendedActions;
    }

    @AuraEnabled(cacheable=false)
    public static InvestigationResponse investigate(InvestigationRequest request) {
        InvestigationResponse response = new InvestigationResponse();
        response.groundingFacts = new List<String>();
        response.recommendedActions = new List<String>();

        if (request == null) {
            response.summary = 'No investigation request was provided.';
            return response;
        }

        response.groundingFacts.add('Question: ' + request.question);
        if (request.recordId != null && !String.isBlank(request.objectApiName)) {
            response.groundingFacts.addAll(loadRecordFacts(request.objectApiName, request.recordId));
        }
        response.groundingFacts.addAll(loadOrgQualityFacts());

        response.summary = 'Agentforce grounding package prepared for CRM data quality investigation.';
        response.recommendedActions.add('Review duplicate candidates before executing merges.');
        response.recommendedActions.add('Prioritize failed rows caused by required fields or duplicate conflicts.');
        response.recommendedActions.add('Use CRM Analytics to compare import volume, failure rate, and downstream record changes.');
        return response;
    }

    private static List<String> loadRecordFacts(String objectApiName, Id recordId) {
        if (objectApiName == 'Account') {
            Account accountRecord = [
                SELECT Id, Name, Website, BillingCity, BillingCountry, LastModifiedDate
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
            return new List<String>{
                'Account: ' + accountRecord.Name,
                'Website: ' + accountRecord.Website,
                'Location: ' + String.join(new List<String>{ accountRecord.BillingCity, accountRecord.BillingCountry }, ', '),
                'Last modified: ' + String.valueOf(accountRecord.LastModifiedDate)
            };
        }
        if (objectApiName == 'Contact') {
            Contact contactRecord = [
                SELECT Id, FirstName, LastName, Email, Account.Name, LastModifiedDate
                FROM Contact
                WHERE Id = :recordId
                LIMIT 1
            ];
            return new List<String>{
                'Contact: ' + String.join(new List<String>{ contactRecord.FirstName, contactRecord.LastName }, ' '),
                'Email: ' + contactRecord.Email,
                'Account: ' + contactRecord.Account.Name,
                'Last modified: ' + String.valueOf(contactRecord.LastModifiedDate)
            };
        }
        if (objectApiName == 'Lead') {
            Lead leadRecord = [
                SELECT Id, FirstName, LastName, Company, Email, Status, LastModifiedDate
                FROM Lead
                WHERE Id = :recordId
                LIMIT 1
            ];
            return new List<String>{
                'Lead: ' + String.join(new List<String>{ leadRecord.FirstName, leadRecord.LastName }, ' '),
                'Company: ' + leadRecord.Company,
                'Status: ' + leadRecord.Status,
                'Last modified: ' + String.valueOf(leadRecord.LastModifiedDate)
            };
        }
        return new List<String>{ 'Unsupported object for grounding: ' + objectApiName };
    }

    private static List<String> loadOrgQualityFacts() {
        return new List<String>{
            'Account count: ' + [SELECT COUNT() FROM Account],
            'Contact count: ' + [SELECT COUNT() FROM Contact],
            'Lead count: ' + [SELECT COUNT() FROM Lead],
            'Open opportunity count: ' + [SELECT COUNT() FROM Opportunity WHERE IsClosed = false]
        };
    }
}