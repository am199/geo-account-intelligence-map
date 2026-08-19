public with sharing class SimilarityUtil {
    public static Decimal normalizedLevenshtein(String leftValue, String rightValue) {
        String leftText = normalize(leftValue);
        String rightText = normalize(rightValue);
        if (String.isBlank(leftText) && String.isBlank(rightText)) {
            return 1;
        }
        Integer maxLength = Math.max(leftText.length(), rightText.length());
        if (maxLength == 0) {
            return 1;
        }
        Integer distance = levenshteinDistance(leftText, rightText);
        return Decimal.valueOf(maxLength - distance) / Decimal.valueOf(maxLength);
    }

    public static Decimal jaroWinkler(String leftValue, String rightValue) {
        String s1 = normalize(leftValue);
        String s2 = normalize(rightValue);
        if (s1 == s2) {
            return 1;
        }
        if (String.isBlank(s1) || String.isBlank(s2)) {
            return 0;
        }

        Integer matchDistance = Math.max(s1.length(), s2.length()) / 2 - 1;
        List<Boolean> s1Matches = new List<Boolean>();
        List<Boolean> s2Matches = new List<Boolean>();
        for (Integer i = 0; i < s1.length(); i++) s1Matches.add(false);
        for (Integer i = 0; i < s2.length(); i++) s2Matches.add(false);

        Integer matches = 0;
        for (Integer i = 0; i < s1.length(); i++) {
            Integer startIndex = Math.max(0, i - matchDistance);
            Integer endIndex = Math.min(i + matchDistance + 1, s2.length());
            for (Integer j = startIndex; j < endIndex; j++) {
                if (s2Matches[j] || s1.substring(i, i + 1) != s2.substring(j, j + 1)) {
                    continue;
                }
                s1Matches[i] = true;
                s2Matches[j] = true;
                matches++;
                break;
            }
        }
        if (matches == 0) {
            return 0;
        }

        Decimal transpositions = 0;
        Integer k = 0;
        for (Integer i = 0; i < s1.length(); i++) {
            if (!s1Matches[i]) continue;
            while (!s2Matches[k]) k++;
            if (s1.substring(i, i + 1) != s2.substring(k, k + 1)) {
                transpositions += 1;
            }
            k++;
        }

        Decimal m = matches;
        Decimal jaro = ((m / s1.length()) + (m / s2.length()) + ((m - (transpositions / 2)) / m)) / 3;
        Integer prefix = 0;
        Integer maxPrefix = Math.min(4, Math.min(s1.length(), s2.length()));
        for (Integer i = 0; i < maxPrefix; i++) {
            if (s1.substring(i, i + 1) == s2.substring(i, i + 1)) {
                prefix++;
            } else {
                break;
            }
        }
        return jaro + (Decimal.valueOf(prefix) * 0.1 * (1 - jaro));
    }

    public static Decimal blendedSimilarity(String leftValue, String rightValue) {
        return (normalizedLevenshtein(leftValue, rightValue) * 0.45) + (jaroWinkler(leftValue, rightValue) * 0.55);
    }

    public static String normalize(String value) {
        if (value == null) {
            return '';
        }
        String normalized = value.toLowerCase().trim();
        normalized = normalized.replaceAll('[^a-z0-9 ]', ' ');
        normalized = normalized.replaceAll('\\b(inc|llc|ltd|corp|corporation|company|co)\\b', '');
        normalized = normalized.replaceAll('\\s+', ' ').trim();
        return normalized;
    }

    private static Integer levenshteinDistance(String s, String t) {
        Integer n = s.length();
        Integer m = t.length();
        if (n == 0) return m;
        if (m == 0) return n;

        List<Integer> previous = new List<Integer>();
        List<Integer> current = new List<Integer>();
        for (Integer j = 0; j <= m; j++) {
            previous.add(j);
            current.add(0);
        }

        for (Integer i = 1; i <= n; i++) {
            current[0] = i;
            for (Integer j = 1; j <= m; j++) {
                Integer cost = s.substring(i - 1, i) == t.substring(j - 1, j) ? 0 : 1;
                current[j] = Math.min(Math.min(current[j - 1] + 1, previous[j] + 1), previous[j - 1] + cost);
            }
            for (Integer j = 0; j <= m; j++) {
                previous[j] = current[j];
            }
        }
        return previous[m];
    }
}