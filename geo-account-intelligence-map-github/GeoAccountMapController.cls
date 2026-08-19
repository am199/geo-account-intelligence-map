public with sharing class GeoAccountMapController {

    // ============================================================
    // FILTER OPTIONS
    // ============================================================

    public class FilterOptions {
        @AuraEnabled public List<OptionItem> industries;
        @AuraEnabled public List<OptionItem> stages;
        @AuraEnabled public List<OptionItem> owners;

        public FilterOptions() {
            industries = new List<OptionItem>();
            stages = new List<OptionItem>();
            owners = new List<OptionItem>();
        }
    }

    public class OptionItem {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public OptionItem(String labelValue, String valueValue) {
            label = labelValue;
            value = valueValue;
        }
    }


    // ============================================================
    // ACCOUNT MAP DATA
    // ============================================================

    public class AccountMapData {

        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;

        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String country;

        @AuraEnabled public String industry;

        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;

        @AuraEnabled public Integer openOpportunities;
        @AuraEnabled public Decimal pipeline;

        @AuraEnabled public String opportunityStage;
        @AuraEnabled public String opportunityOwner;

        @AuraEnabled public String opportunitySignal;

        @AuraEnabled public Decimal distanceMiles;

        public AccountMapData() {
            openOpportunities = 0;
            pipeline = 0;
            distanceMiles = 0;
        }
    }


    // ============================================================
    // INTERNAL OPPORTUNITY DATA
    // ============================================================

    private class OpportunityInfo {

        public Id opportunityId;
        public Id accountId;

        public String stageName;
        public String ownerName;
        public Id ownerId;

        public Decimal amount;

        public OpportunityInfo(
            Id opportunityIdValue,
            Id accountIdValue,
            String stageNameValue,
            String ownerNameValue,
            Id ownerIdValue,
            Decimal amountValue
        ) {
            opportunityId = opportunityIdValue;
            accountId = accountIdValue;
            stageName = stageNameValue;
            ownerName = ownerNameValue;
            ownerId = ownerIdValue;
            amount = amountValue == null ? 0 : amountValue;
        }
    }


    // ============================================================
    // GET FILTER OPTIONS
    // ============================================================

    @AuraEnabled(cacheable=true)
public static FilterOptions getFilterOptions() {

    FilterOptions result = new FilterOptions();

    // ========================================================
    // INDUSTRIES
    // ========================================================

    Set<String> industrySet = new Set<String>();

    for (Account acc : [
        SELECT Industry
        FROM Account
        WHERE Industry != null
        ORDER BY Industry
    ]) {
        if (String.isNotBlank(acc.Industry)) {
            industrySet.add(acc.Industry);
        }
    }

    List<String> industries = new List<String>();
    industries.addAll(industrySet);
    industries.sort();

    for (String industry : industries) {
        result.industries.add(
            new OptionItem(
                industry,
                industry
            )
        );
    }

    // ========================================================
    // OPPORTUNITY STAGES
    // ========================================================

    Set<String> stageSet = new Set<String>();

    for (Opportunity opp : [
        SELECT StageName
        FROM Opportunity
        WHERE StageName != null
        ORDER BY StageName
    ]) {
        if (String.isNotBlank(opp.StageName)) {
            stageSet.add(opp.StageName);
        }
    }

    List<String> stages = new List<String>();
    stages.addAll(stageSet);
    stages.sort();

    for (String stage : stages) {
        result.stages.add(
            new OptionItem(
                stage,
                stage
            )
        );
    }

    // ========================================================
    // OPPORTUNITY OWNERS
    // ========================================================

    Map<Id, String> ownerMap =
        new Map<Id, String>();

    for (Opportunity opp : [
        SELECT OwnerId, Owner.Name
        FROM Opportunity
        WHERE OwnerId != null
        ORDER BY Owner.Name
    ]) {

        if (opp.Owner != null) {

            ownerMap.put(
                opp.OwnerId,
                opp.Owner.Name
            );
        }
    }

    List<String> ownerNames =
        new List<String>();

    ownerNames.addAll(
        ownerMap.values()
    );

    ownerNames.sort();

    for (String ownerName : ownerNames) {

        for (Id ownerId : ownerMap.keySet()) {

            if (
                ownerMap.get(ownerId) ==
                ownerName
            ) {

                result.owners.add(
                    new OptionItem(
                        ownerName,
                        String.valueOf(ownerId)
                    )
                );

                break;
            }
        }
    }

    return result;
}


    // ============================================================
    // GET MAP DATA
    // ============================================================

    @AuraEnabled
public static List<AccountMapData> getMapData(
    String industry,
    String opportunityStage,
    String opportunityOwnerId,
    Decimal radiusMiles,
    Decimal centerLatitude,
    Decimal centerLongitude
) {

    List<AccountMapData> results = new List<AccountMapData>();

    // ========================================================
    // NORMALIZE FILTERS
    // ========================================================

    String cleanIndustry = normalizeFilter(industry);
    String cleanStage = normalizeFilter(opportunityStage);
    String cleanOwnerId = normalizeFilter(opportunityOwnerId);

    // ========================================================
    // MAP CENTER
    // ========================================================

    Double mapCenterLat;
    Double mapCenterLon;

    /*
     * IMPORTANT:
     *
     * The LWC sends the USA map center.
     *
     * We do NOT use Pune here.
     */

    if (centerLatitude != null && centerLongitude != null) {

        mapCenterLat = toDouble(centerLatitude);
        mapCenterLon = toDouble(centerLongitude);

    } else {

        mapCenterLat = 39.8283;
mapCenterLon = -98.5795;
    }

    // ========================================================
    // RADIUS
    // ========================================================

    Boolean useRadius = false;
    Double requestedRadius = null;

    if (radiusMiles != null && radiusMiles > 0) {

        useRadius = true;
        requestedRadius = toDouble(radiusMiles);
    }

    // ========================================================
    // LOAD ACCOUNTS
    // ========================================================

    List<Account> accounts = [
        SELECT
            Id,
            Name,
            BillingCity,
            BillingState,
            BillingCountry,
            BillingLatitude,
            BillingLongitude,
            Industry
        FROM Account
        ORDER BY Name
    ];

    // ========================================================
    // LOAD OPEN OPPORTUNITIES
    // ========================================================

    List<Opportunity> opportunities = [
        SELECT
            Id,
            AccountId,
            Name,
            Amount,
            StageName,
            OwnerId,
            Owner.Name,
            IsClosed
        FROM Opportunity
        WHERE IsClosed = false
        AND AccountId != null
    ];

    // ========================================================
    // CREATE OPPORTUNITY MAP
    // ========================================================

    Map<Id, List<OpportunityInfo>> opportunitiesByAccount =
        new Map<Id, List<OpportunityInfo>>();

    for (Opportunity opp : opportunities) {

        // ----------------------------------------------------
        // STAGE FILTER
        // ----------------------------------------------------

        if (
            String.isNotBlank(cleanStage) &&
            opp.StageName != cleanStage
        ) {
            continue;
        }

        // ----------------------------------------------------
        // OWNER FILTER
        // ----------------------------------------------------

        if (String.isNotBlank(cleanOwnerId)) {

            if (
                opp.OwnerId == null ||
                String.valueOf(opp.OwnerId) != cleanOwnerId
            ) {
                continue;
            }
        }

        // ----------------------------------------------------
        // CREATE OPPORTUNITY INFO
        // ----------------------------------------------------

        OpportunityInfo info = new OpportunityInfo(
            opp.Id,
            opp.AccountId,
            opp.StageName,
            opp.Owner != null ? opp.Owner.Name : null,
            opp.OwnerId,
            opp.Amount
        );

        if (!opportunitiesByAccount.containsKey(opp.AccountId)) {

            opportunitiesByAccount.put(
                opp.AccountId,
                new List<OpportunityInfo>()
            );
        }

        opportunitiesByAccount
            .get(opp.AccountId)
            .add(info);
    }

    // ========================================================
    // PROCESS ACCOUNTS
    // ========================================================

    for (Account acc : accounts) {

        // ====================================================
        // INDUSTRY FILTER
        // ====================================================

        if (String.isNotBlank(cleanIndustry)) {

            if (acc.Industry != cleanIndustry) {
                continue;
            }
        }

        // ====================================================
        // COORDINATES
        // ====================================================

        if (
            acc.BillingLatitude == null ||
            acc.BillingLongitude == null
        ) {
            continue;
        }

        Double accountLat =
            toDouble(acc.BillingLatitude);

        Double accountLon =
            toDouble(acc.BillingLongitude);

        // ====================================================
        // CALCULATE DISTANCE
        // ====================================================

        Double distance = calculateDistanceMiles(
            mapCenterLat,
            mapCenterLon,
            accountLat,
            accountLon
        );

        // ====================================================
        // RADIUS FILTER
        // ====================================================

        if (useRadius) {

   

    System.debug(
        '===== RADIUS CHECK ====='
    );

    System.debug(
        'Account: ' + acc.Name
    );

    System.debug(
        'Account Latitude: ' + accountLat
    );

    System.debug(
        'Account Longitude: ' + accountLon
    );

    System.debug(
        'Center Latitude: ' + mapCenterLat
    );

    System.debug(
        'Center Longitude: ' + mapCenterLon
    );

    System.debug(
        'Calculated Distance: ' + distance
    );

    System.debug(
        'Requested Radius: ' + requestedRadius
    );

    if (distance > requestedRadius) {

        System.debug(
            'RESULT: ACCOUNT EXCLUDED'
        );

        continue;
    }

    System.debug(
        'RESULT: ACCOUNT INCLUDED'
    );
}

        // ====================================================
        // OPPORTUNITIES FOR THIS ACCOUNT
        // ====================================================

        List<OpportunityInfo> accountOpps =
            opportunitiesByAccount.get(acc.Id);

        // ----------------------------------------------------
        // Stage / Owner filter requires matching opportunity
        // ----------------------------------------------------

        if (
            (
                String.isNotBlank(cleanStage) ||
                String.isNotBlank(cleanOwnerId)
            )
            &&
            (
                accountOpps == null ||
                accountOpps.isEmpty()
            )
        ) {
            continue;
        }

        // ====================================================
        // CREATE MAP DATA
        // ====================================================

        AccountMapData data = new AccountMapData();

        data.accountId = acc.Id;
        data.accountName = acc.Name;

        data.city = acc.BillingCity;
        data.state = acc.BillingState;
        data.country = acc.BillingCountry;

        data.industry = acc.Industry;

        data.latitude = acc.BillingLatitude;
        data.longitude = acc.BillingLongitude;

        data.distanceMiles =
            Decimal.valueOf(
                String.valueOf(
                    Math.round(distance * 100) / 100.0
                )
            );

        // ====================================================
        // OPPORTUNITY INFORMATION
        // ====================================================

        if (
            accountOpps != null &&
            !accountOpps.isEmpty()
        ) {

            Decimal totalPipeline = 0;

            Set<String> stageNames =
                new Set<String>();

            Set<String> ownerNames =
                new Set<String>();

            for (OpportunityInfo oppInfo : accountOpps) {

                data.openOpportunities++;

                totalPipeline +=
                    oppInfo.amount == null
                    ? 0
                    : oppInfo.amount;

                if (
                    String.isNotBlank(
                        oppInfo.stageName
                    )
                ) {
                    stageNames.add(
                        oppInfo.stageName
                    );
                }

                if (
                    String.isNotBlank(
                        oppInfo.ownerName
                    )
                ) {
                    ownerNames.add(
                        oppInfo.ownerName
                    );
                }
            }

            data.pipeline = totalPipeline;

            // ------------------------------------------------
            // DISPLAY STAGE
            // ------------------------------------------------

            List<String> sortedStages =
                new List<String>();

            sortedStages.addAll(stageNames);
            sortedStages.sort();

            if (!sortedStages.isEmpty()) {

                data.opportunityStage =
                    String.join(
                        sortedStages,
                        ', '
                    );
            }

            // ------------------------------------------------
            // DISPLAY OWNER
            // ------------------------------------------------

            List<String> sortedOwners =
                new List<String>();

            sortedOwners.addAll(ownerNames);
            sortedOwners.sort();

            if (!sortedOwners.isEmpty()) {

                data.opportunityOwner =
                    String.join(
                        sortedOwners,
                        ', '
                    );
            }

            // ------------------------------------------------
            // SIGNAL
            // ------------------------------------------------

            data.opportunitySignal =
                determineSignal(
                    data.openOpportunities,
                    data.pipeline
                );

        } else {

            data.openOpportunities = 0;
            data.pipeline = 0;
            data.opportunityStage = null;
            data.opportunityOwner = null;
            data.opportunitySignal = 'Low';
        }

        results.add(data);
    }

    // ========================================================
    // SORT BY DISTANCE
    // ========================================================

    sortByDistance(results);

    return results;
}


    // ============================================================
    // NORMALIZE FILTER
    // ============================================================

    private static String normalizeFilter(String value) {

        if (String.isBlank(value)) {
            return null;
        }

        String cleaned = value.trim();

        if (
            cleaned == 'All Industries' ||
            cleaned == 'All Stages' ||
            cleaned == 'All Owners' ||
            cleaned == 'Select an Option' ||
            cleaned == 'null' ||
            cleaned == 'undefined'
        ) {
            return null;
        }

        return cleaned;
    }


    // ============================================================
    // DECIMAL TO DOUBLE
    // ============================================================

    private static Double toDouble(Decimal value) {

        if (value == null) {
            return null;
        }

        return Double.valueOf(
            String.valueOf(value)
        );
    }


    // ============================================================
    // HAVERSINE DISTANCE
    //
    // Returns distance in miles.
    // ============================================================

    private static Double calculateDistanceMiles(
        Double lat1,
        Double lon1,
        Double lat2,
        Double lon2
    ) {

        if (
            lat1 == null ||
            lon1 == null ||
            lat2 == null ||
            lon2 == null
        ) {
            return 0;
        }


        Double earthRadiusMiles = 3958.761;


        Double dLat =
            (lat2 - lat1) *
            Math.PI /
            180;


        Double dLon =
            (lon2 - lon1) *
            Math.PI /
            180;


        Double lat1Radians =
            lat1 *
            Math.PI /
            180;


        Double lat2Radians =
            lat2 *
            Math.PI /
            180;


        Double sinLat =
            Math.sin(dLat / 2);


        Double sinLon =
            Math.sin(dLon / 2);


        Double a =
            (sinLat * sinLat)
            +
            (
                Math.cos(lat1Radians)
                *
                Math.cos(lat2Radians)
                *
                sinLon
                *
                sinLon
            );


        // Protect against tiny floating-point errors.
        if (a < 0) {
            a = 0;
        }

        if (a > 1) {
            a = 1;
        }


        Double c =
            2 *
            Math.atan2(
                Math.sqrt(a),
                Math.sqrt(1 - a)
            );


        return earthRadiusMiles * c;
    }


    // ============================================================
    // OPPORTUNITY SIGNAL
    // ============================================================

    private static String determineSignal(
        Integer opportunityCount,
        Decimal pipeline
    ) {

        Decimal pipelineValue =
            pipeline == null
            ? 0
            : pipeline;


        // High:
        // Strong pipeline or several open opportunities.

        if (
            pipelineValue >= 100000 ||
            opportunityCount >= 3
        ) {
            return 'High';
        }


        // Medium:
        // Some opportunity activity.

        if (
            pipelineValue > 0 ||
            opportunityCount > 0
        ) {
            return 'Medium';
        }


        // Low:
        // No meaningful opportunity activity.

        return 'Low';
    }


    // ============================================================
    // SORT BY DISTANCE
    // ============================================================

    private static void sortByDistance(
        List<AccountMapData> dataList
    ) {

        // Simple insertion sort.
        // Number of accounts in this project is expected to be
        // relatively small.

        for (
            Integer i = 1;
            i < dataList.size();
            i++
        ) {

            AccountMapData current =
                dataList[i];

            Integer j = i - 1;


            while (
                j >= 0 &&
                dataList[j].distanceMiles >
                current.distanceMiles
            ) {

                dataList[j + 1] =
                    dataList[j];

                j--;
            }


            dataList[j + 1] =
                current;
        }
    }
}