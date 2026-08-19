public with sharing class DealHealthController {

    @AuraEnabled(cacheable=true)
    public static DealCoachService.DealContext getDealHealth(
        Id opportunityId
    ) {

        return DealCoachService.buildContext(
            opportunityId
        );
    }
}