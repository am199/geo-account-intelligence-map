public with sharing class ChildRelationshipService {
    public class ImpactSummary {
        @AuraEnabled public Integer opportunityCount;
        @AuraEnabled public Decimal opportunityAmount;
        @AuraEnabled public Integer caseCount;
        @AuraEnabled public Integer contactCount;
        @AuraEnabled public List<String> notes;
    }

    @AuraEnabled(cacheable=true)
    public static ImpactSummary summarizeAccountMergeImpact(List<Id> accountIds) {
        ImpactSummary summary = new ImpactSummary();
        summary.notes = new List<String>();
        if (accountIds == null || accountIds.isEmpty()) {
            summary.opportunityCount = 0;
            summary.opportunityAmount = 0;
            summary.caseCount = 0;
            summary.contactCount = 0;
            return summary;
        }

        AggregateResult opportunityRollup = [
            SELECT COUNT(Id) recordCount, SUM(Amount) totalAmount
            FROM Opportunity
            WHERE AccountId IN :accountIds
        ];
        summary.opportunityCount = (Integer) opportunityRollup.get('recordCount');
        summary.opportunityAmount = (Decimal) opportunityRollup.get('totalAmount');
        if (summary.opportunityAmount == null) summary.opportunityAmount = 0;

        summary.caseCount = [SELECT COUNT() FROM Case WHERE AccountId IN :accountIds];
        summary.contactCount = [SELECT COUNT() FROM Contact WHERE AccountId IN :accountIds];

        if (summary.opportunityCount > 0) summary.notes.add('Pipeline will be consolidated onto the master Account.');
        if (summary.caseCount > 0) summary.notes.add('Support history should be reviewed before merge.');
        if (summary.contactCount > 0) summary.notes.add('Contacts may require reassignment validation after merge.');
        return summary;
    }
}