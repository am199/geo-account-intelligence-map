public with sharing class ImportErrorAnalyzer {
    public class ErrorInsight {
        @AuraEnabled public String category;
        @AuraEnabled public String recommendation;
        @AuraEnabled public String severity;
    }

    @AuraEnabled(cacheable=true)
    public static ErrorInsight analyze(String errorMessage) {
        ErrorInsight insight = new ErrorInsight();
        String message = String.isBlank(errorMessage) ? '' : errorMessage.toLowerCase();

        if (message.contains('required') || message.contains('missing')) {
            insight.category = 'Missing Required Data';
            insight.recommendation = 'Populate the required field or adjust the target object mapping before retrying.';
            insight.severity = 'High';
        } else if (message.contains('duplicate')) {
            insight.category = 'Duplicate Conflict';
            insight.recommendation = 'Review matching records in the duplicate workbench before retrying this row.';
            insight.severity = 'Medium';
        } else if (message.contains('invalid') || message.contains('malformed')) {
            insight.category = 'Invalid Field Value';
            insight.recommendation = 'Normalize the source value to match Salesforce field format, picklist values, or validation rules.';
            insight.severity = 'Medium';
        } else {
            insight.category = 'General Import Failure';
            insight.recommendation = 'Inspect row values, validation rules, duplicate rules, and required lookup relationships.';
            insight.severity = 'Low';
        }
        return insight;
    }
}