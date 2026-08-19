public with sharing class CsvParserService {
    public class ParsedCsv {
        @AuraEnabled public List<String> headers;
        @AuraEnabled public List<Map<String, String>> rows;
        @AuraEnabled public Integer rowCount;
        @AuraEnabled public List<String> warnings;
    }

    @AuraEnabled(cacheable=false)
    public static Id uploadCsvFile(String fileName, String base64Data) {
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('File name and file data are required.');
        }

        ContentVersion version = new ContentVersion(
            Title = fileName.endsWith('.csv') ? fileName.substring(0, fileName.length() - 4) : fileName,
            PathOnClient = fileName,
            VersionData = EncodingUtil.base64Decode(base64Data)
        );
        insert version;

        return version.Id;
    }

    @AuraEnabled(cacheable=false)
    public static ParsedCsv parseContentVersion(Id contentVersionId) {
        ContentVersion version = [
            SELECT Id, VersionData
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];
        return parseCsv(version.VersionData.toString());
    }

    @AuraEnabled(cacheable=false)
    public static ParsedCsv parseCsv(String csvText) {
        ParsedCsv result = new ParsedCsv();
        result.headers = new List<String>();
        result.rows = new List<Map<String, String>>();
        result.warnings = new List<String>();

        List<List<String>> matrix = parseRows(csvText);
        if (matrix.isEmpty()) {
            result.rowCount = 0;
            result.warnings.add('The uploaded CSV did not contain any rows.');
            return result;
        }

        for (String header : matrix[0]) {
            result.headers.add(normalizeHeader(header));
        }

        for (Integer i = 1; i < matrix.size(); i++) {
            List<String> line = matrix[i];
            if (isBlankRow(line)) {
                continue;
            }
            Map<String, String> row = new Map<String, String>();
            for (Integer h = 0; h < result.headers.size(); h++) {
                row.put(result.headers[h], h < line.size() ? line[h].trim() : null);
            }
            if (line.size() != result.headers.size()) {
                result.warnings.add('Row ' + i + ' has ' + line.size() + ' columns; expected ' + result.headers.size() + '.');
            }
            result.rows.add(row);
        }
        result.rowCount = result.rows.size();
        return result;
    }

    public static List<List<String>> parseRows(String csvText) {
        List<List<String>> rows = new List<List<String>>();
        if (String.isBlank(csvText)) {
            return rows;
        }

        List<String> row = new List<String>();
        String cell = '';
        Boolean quoted = false;

        for (Integer i = 0; i < csvText.length(); i++) {
            String c = csvText.substring(i, i + 1);
            if (c == '"') {
                if (quoted && i + 1 < csvText.length() && csvText.substring(i + 1, i + 2) == '"') {
                    cell += '"';
                    i++;
                } else {
                    quoted = !quoted;
                }
            } else if (c == ',' && !quoted) {
                row.add(cell);
                cell = '';
            } else if ((c == '\n' || c == '\r') && !quoted) {
                if (c == '\r' && i + 1 < csvText.length() && csvText.substring(i + 1, i + 2) == '\n') {
                    i++;
                }
                row.add(cell);
                rows.add(row);
                row = new List<String>();
                cell = '';
            } else {
                cell += c;
            }
        }

        row.add(cell);
        rows.add(row);
        return rows;
    }

    private static String normalizeHeader(String value) {
        if (String.isBlank(value)) {
            return 'Unnamed_Field';
        }
        return value.trim().replaceAll('\\s+', '_');
    }

    private static Boolean isBlankRow(List<String> row) {
        for (String value : row) {
            if (!String.isBlank(value)) {
                return false;
            }
        }
        return true;
    }
}