public with sharing class DocumentTemplateService {

    public class TemplateOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String description;
        @AuraEnabled public String documentType;
    }

    @AuraEnabled(cacheable=true)
    public static List<TemplateOption> getTemplates() {

        List<TemplateOption> results =
            new List<TemplateOption>();

        for (
            Document_Template__mdt template :
            [
                SELECT
                    DeveloperName,
                    Template_Name__c,
                    Visualforce_Page__c,
                    Document_Type__c,
                    Active__c,
                    Description__c
                FROM Document_Template__mdt
                WHERE Active__c = true
                ORDER BY Template_Name__c
            ]
        ) {

            TemplateOption option =
                new TemplateOption();

            option.label =
                template.Template_Name__c;

            option.value =
                template.DeveloperName;

            option.description =
                template.Description__c;

            option.documentType =
                template.Document_Type__c;

            results.add(option);
        }

        return results;
    }
}