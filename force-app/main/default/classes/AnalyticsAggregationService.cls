public with sharing class AnalyticsAggregationService {
    public class DashboardMetric {
        @AuraEnabled public String label;
        @AuraEnabled public Decimal value;
        @AuraEnabled public String detail;
    }

    @AuraEnabled(cacheable=true)
    public static List<DashboardMetric> getOperationalMetrics() {
        List<DashboardMetric> metrics = new List<DashboardMetric>();
        metrics.add(metric('Accounts', [SELECT COUNT() FROM Account], 'Customer master records in scope'));
        metrics.add(metric('Contacts', [SELECT COUNT() FROM Contact], 'People records in scope'));
        metrics.add(metric('Leads', [SELECT COUNT() FROM Lead], 'Raw inbound records available for cleanup'));
        metrics.add(metric('Open Cases', [SELECT COUNT() FROM Case WHERE IsClosed = false], 'Support history requiring merge visibility'));
        metrics.add(metric('Open Pipeline', [SELECT COUNT() FROM Opportunity WHERE IsClosed = false], 'Pipeline records potentially affected by duplicates'));
        return metrics;
    }

    private static DashboardMetric metric(String label, Decimal value, String detail) {
        DashboardMetric item = new DashboardMetric();
        item.label = label;
        item.value = value;
        item.detail = detail;
        return item;
    }
}