public with sharing class DuplicateDetectionService {
    public class DuplicateCandidate {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String displayName;
        @AuraEnabled public String secondaryValue;
        @AuraEnabled public Decimal score;
        @AuraEnabled public String reason;
    }

    @AuraEnabled(cacheable=true)
    public static List<DuplicateCandidate> findAccountDuplicates(String accountName, String website, Integer limitSize) {
        Integer rowLimit = limitSize == null ? 25 : Math.min(limitSize, 100);
        String token = '%' + firstSearchToken(accountName) + '%';
        List<Account> accounts = [
            SELECT Id, Name, Website, BillingCity, BillingCountry
            FROM Account
            WHERE Name LIKE :token
            ORDER BY LastModifiedDate DESC
            LIMIT :rowLimit
        ];

        List<DuplicateCandidate> candidates = new List<DuplicateCandidate>();
        for (Account accountRecord : accounts) {
            Decimal nameScore = SimilarityUtil.blendedSimilarity(accountName, accountRecord.Name);
            Decimal websiteScore = String.isBlank(website) || String.isBlank(accountRecord.Website)
                ? 0
                : SimilarityUtil.blendedSimilarity(website, accountRecord.Website);
            Decimal score = (nameScore * 0.75) + (websiteScore * 0.25);
            candidates.add(candidate(accountRecord.Id, 'Account', accountRecord.Name, accountRecord.Website, score, score >= 0.85 ? 'Strong name and domain similarity' : 'Possible naming similarity'));
        }
        candidates.sort(new DuplicateCandidateSorter());
        return candidates;
    }

    @AuraEnabled(cacheable=true)
    public static List<DuplicateCandidate> findContactDuplicates(String firstName, String lastName, String email, Integer limitSize) {
        Integer rowLimit = limitSize == null ? 25 : Math.min(limitSize, 100);
        String emailToken = String.isBlank(email) ? null : email;
        String lastNameToken = '%' + firstSearchToken(lastName) + '%';
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Email, Account.Name
            FROM Contact
            WHERE Email = :emailToken OR LastName LIKE :lastNameToken
            ORDER BY LastModifiedDate DESC
            LIMIT :rowLimit
        ];

        List<DuplicateCandidate> candidates = new List<DuplicateCandidate>();
        String incomingName = String.join(new List<String>{ firstName, lastName }, ' ');
        for (Contact contactRecord : contacts) {
            String existingName = String.join(new List<String>{ contactRecord.FirstName, contactRecord.LastName }, ' ');
            Decimal nameScore = SimilarityUtil.blendedSimilarity(incomingName, existingName);
            Decimal emailScore = String.isBlank(email) || String.isBlank(contactRecord.Email)
                ? 0
                : SimilarityUtil.blendedSimilarity(email, contactRecord.Email);
            Decimal score = (nameScore * 0.5) + (emailScore * 0.5);
            candidates.add(candidate(contactRecord.Id, 'Contact', existingName, contactRecord.Email, score, emailScore == 1 ? 'Exact email match' : 'Possible person match'));
        }
        candidates.sort(new DuplicateCandidateSorter());
        return candidates;
    }

    private static DuplicateCandidate candidate(Id recordId, String objectApiName, String displayName, String secondaryValue, Decimal score, String reason) {
        DuplicateCandidate item = new DuplicateCandidate();
        item.recordId = recordId;
        item.objectApiName = objectApiName;
        item.displayName = displayName;
        item.secondaryValue = secondaryValue;
        item.score = score.setScale(3);
        item.reason = reason;
        return item;
    }

    private static String firstSearchToken(String value) {
        String normalized = SimilarityUtil.normalize(value);
        if (String.isBlank(normalized)) {
            return '';
        }
        return normalized.split(' ')[0];
    }

    public class DuplicateCandidateSorter implements Comparator<DuplicateCandidate> {
        public Integer compare(DuplicateCandidate a, DuplicateCandidate b) {
            if (a.score == b.score) return 0;
            return a.score > b.score ? -1 : 1;
        }
    }
}