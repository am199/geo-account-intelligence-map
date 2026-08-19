public with sharing class BulkImportOrchestrator {
    public class ImportRequest {
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String fieldMappingJson;
        @AuraEnabled public Boolean dryRun;
    }

    public class ImportResult {
        @AuraEnabled public String importId;
        @AuraEnabled public String status;
        @AuraEnabled public Integer totalRows;
        @AuraEnabled public Integer successRows;
        @AuraEnabled public Integer failedRows;
        @AuraEnabled public List<String> errors;
    }

    @AuraEnabled(cacheable=false)
    public static ImportResult startImport(ImportRequest request) {
        validateRequest(request);
        String importId = 'IMP-' + String.valueOf(DateTime.now().getTime());
        CsvParserService.ParsedCsv parsed = CsvParserService.parseContentVersion(request.contentVersionId);
        Map<String, String> mappings = parseMappings(request.fieldMappingJson);

        ImportResult result = new ImportResult();
        result.importId = importId;
        result.totalRows = parsed.rowCount;
        result.successRows = 0;
        result.failedRows = 0;
        result.errors = new List<String>();

        PlatformEventPublisher.importProgress(importId, 'Started', 0, parsed.rowCount, 'Import started for ' + request.objectApiName + '.');
        if (request.dryRun == true) {
            result.status = 'RiskAnalyzed';
            result.errors.addAll(parsed.warnings);
            PlatformEventPublisher.importProgress(importId, 'RiskAnalyzed', 0, parsed.rowCount, 'Dry run completed. No records were committed.');
            return result;
        }

        List<SObject> records = new List<SObject>();
        for (Map<String, String> row : parsed.rows) {
            records.add(toSObject(request.objectApiName, row, mappings));
        }

        Database.SaveResult[] saveResults = Database.insert(records, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            if (saveResults[i].isSuccess()) {
                result.successRows++;
            } else {
                result.failedRows++;
                String errorMessage = saveResults[i].getErrors()[0].getMessage();
                result.errors.add('Row ' + (i + 1) + ': ' + errorMessage);
                PlatformEventPublisher.importError(importId, i + 1, request.objectApiName, errorMessage, JSON.serialize(parsed.rows[i]));
            }

            Integer processedCount = i + 1;
            if (processedCount == (processedCount / 25) * 25 || i == saveResults.size() - 1) {
                PlatformEventPublisher.importProgress(importId, 'Running', processedCount, parsed.rowCount, 'Processed ' + processedCount + ' rows.');
            }
        }

        result.status = result.failedRows == 0 ? 'Completed' : 'CompletedWithErrors';
        PlatformEventPublisher.importProgress(importId, result.status, parsed.rowCount, parsed.rowCount, 'Import finished with ' + result.failedRows + ' failed rows.');
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> describeCreateableFields(String objectApiName) {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null) {
            throw new AuraHandledException('Unsupported object: ' + objectApiName);
        }
        List<String> fields = new List<String>();
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult describe = fieldMap.get(fieldName).getDescribe();
            if (describe.isCreateable()) {
                fields.add(fieldName);
            }
        }
        fields.sort();
        return fields;
    }

    private static void validateRequest(ImportRequest request) {
        if (request == null || request.contentVersionId == null || String.isBlank(request.objectApiName)) {
            throw new AuraHandledException('contentVersionId and objectApiName are required.');
        }
        Set<String> allowed = new Set<String>{ 'Account', 'Contact', 'Lead' };
        if (!allowed.contains(request.objectApiName)) {
            throw new AuraHandledException('Imports are limited to Account, Contact, and Lead.');
        }
    }

    private static Map<String, String> parseMappings(String mappingJson) {
        Map<String, String> result = new Map<String, String>();
        if (String.isBlank(mappingJson)) {
            return result;
        }
        Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(mappingJson);
        for (String key : raw.keySet()) {
            if (raw.get(key) != null) {
                result.put(key, String.valueOf(raw.get(key)));
            }
        }
        return result;
    }

    private static SObject toSObject(String objectApiName, Map<String, String> row, Map<String, String> mappings) {
        SObject record = Schema.getGlobalDescribe().get(objectApiName).newSObject();
        Map<String, Schema.SObjectField> targetFields = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        for (String sourceField : row.keySet()) {
            String targetField = mappings.containsKey(sourceField) ? mappings.get(sourceField) : sourceField;
            if (String.isBlank(targetField) || !targetFields.containsKey(targetField)) {
                continue;
            }
            Schema.DescribeFieldResult fieldDescribe = targetFields.get(targetField).getDescribe();
            if (!fieldDescribe.isCreateable()) {
                continue;
            }
            record.put(targetField, coerceValue(row.get(sourceField), fieldDescribe.getType()));
        }
        return record;
    }

    private static Object coerceValue(String value, Schema.DisplayType fieldType) {
        if (String.isBlank(value)) {
            return null;
        }
        if (fieldType == Schema.DisplayType.Boolean) return value.toLowerCase() == 'true' || value == '1' || value.toLowerCase() == 'yes';
        if (fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Double || fieldType == Schema.DisplayType.Percent) return Decimal.valueOf(value);
        if (fieldType == Schema.DisplayType.Integer) return Integer.valueOf(value);
        if (fieldType == Schema.DisplayType.Date) return Date.valueOf(value);
        if (fieldType == Schema.DisplayType.DateTime) return DateTime.valueOf(value);
        return value;
    }
}