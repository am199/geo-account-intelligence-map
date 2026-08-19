public with sharing class DealCoachService {

    public class DealContext {

        @AuraEnabled
        public Id opportunityId;

        @AuraEnabled
        public String opportunityName;

        @AuraEnabled
        public String stageName;

        @AuraEnabled
        public Decimal amount;

        @AuraEnabled
        public Date closeDate;

        @AuraEnabled
        public String accountName;

        @AuraEnabled
        public Integer daysInStage;

        @AuraEnabled
        public Integer daysSinceLastActivity;

        @AuraEnabled
        public Integer contactCount;

        @AuraEnabled
        public Integer openTaskCount;

        @AuraEnabled
        public Integer overdueTaskCount;

        @AuraEnabled
        public Boolean decisionMakerPresent;

        @AuraEnabled
        public Integer healthScore;

        @AuraEnabled
        public String healthStatus;

        @AuraEnabled
        public List<String> riskSignals;

        @AuraEnabled
        public List<String> positiveSignals;

        @AuraEnabled
        public List<ContactSummary> contacts;

        @AuraEnabled
        public List<TaskSummary> tasks;
    }

    public class ContactSummary {

        @AuraEnabled
        public Id contactId;

        @AuraEnabled
        public String name;

        @AuraEnabled
        public String title;

        @AuraEnabled
        public Boolean isDecisionMaker;
    }

    public class TaskSummary {

        @AuraEnabled
        public Id taskId;

        @AuraEnabled
        public String subject;

        @AuraEnabled
        public Date activityDate;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public String priority;

        @AuraEnabled
        public Boolean overdue;
    }


    public static DealContext buildContext(Id opportunityId) {

        if (opportunityId == null) {
            throw new AuraHandledException(
                'Opportunity Id is required.'
            );
        }

        Opportunity opp = [
            SELECT
                Id,
                Name,
                StageName,
                Amount,
                CloseDate,
                CreatedDate,
                LastActivityDate,
                AccountId,
                Account.Name
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH USER_MODE
            LIMIT 1
        ];

        DealContext context = new DealContext();

        context.opportunityId = opp.Id;
        context.opportunityName = opp.Name;
        context.stageName = opp.StageName;
        context.amount = opp.Amount;
        context.closeDate = opp.CloseDate;
        context.accountName =
            opp.Account != null
                ? opp.Account.Name
                : null;


        /*
         * Calculate stage age approximately from
         * Opportunity CreatedDate.
         *
         * For a production implementation you could
         * use Field History tracking to calculate the
         * actual time spent in the current stage.
         */

        context.daysInStage =
            opp.CreatedDate.date().daysBetween(Date.today());


        /*
         * Last activity
         */

        if (opp.LastActivityDate != null) {

            context.daysSinceLastActivity =
                opp.LastActivityDate.daysBetween(
                    Date.today()
                );

        } else {

            context.daysSinceLastActivity = 999;
        }


        /*
         * Opportunity Contact Roles
         */

        List<OpportunityContactRole> roles = [
            SELECT
                ContactId,
                Contact.Name,
                Contact.Title,
                IsPrimary,
                Role
            FROM OpportunityContactRole
            WHERE OpportunityId = :opportunityId
            WITH USER_MODE
        ];

        context.contacts =
            new List<ContactSummary>();

        Boolean decisionMakerFound = false;

        for (OpportunityContactRole role : roles) {

            ContactSummary contact =
                new ContactSummary();

            contact.contactId =
                role.ContactId;

            contact.name =
                role.Contact != null
                    ? role.Contact.Name
                    : null;

            contact.title =
                role.Contact != null
                    ? role.Contact.Title
                    : null;

            contact.isDecisionMaker =
                isDecisionMaker(
                    role.Role,
                    role.Contact != null
                        ? role.Contact.Title
                        : null
                );

            if (contact.isDecisionMaker) {
                decisionMakerFound = true;
            }

            context.contacts.add(contact);
        }

        context.contactCount =
            context.contacts.size();

        context.decisionMakerPresent =
            decisionMakerFound;


        /*
         * Tasks
         */

        List<Task> tasks = [
            SELECT
                Id,
                Subject,
                ActivityDate,
                Status,
                Priority
            FROM Task
            WHERE WhatId = :opportunityId
            AND IsClosed = false
            WITH USER_MODE
            ORDER BY ActivityDate ASC
            LIMIT 50
        ];

        context.tasks =
            new List<TaskSummary>();

        Integer overdueCount = 0;

        for (Task task : tasks) {

            TaskSummary taskSummary =
                new TaskSummary();

            taskSummary.taskId =
                task.Id;

            taskSummary.subject =
                task.Subject;

            taskSummary.activityDate =
                task.ActivityDate;

            taskSummary.status =
                task.Status;

            taskSummary.priority =
                task.Priority;

            taskSummary.overdue =
                task.ActivityDate != null &&
                task.ActivityDate < Date.today();

            if (taskSummary.overdue) {
                overdueCount++;
            }

            context.tasks.add(taskSummary);
        }

        context.openTaskCount =
            context.tasks.size();

        context.overdueTaskCount =
            overdueCount;


        /*
         * Calculate health score.
         */

        calculateHealth(context);

        return context;
    }


    private static Boolean isDecisionMaker(
        String role,
        String title
    ) {

        String combined =
            (
                String.valueOf(role) +
                ' ' +
                String.valueOf(title)
            ).toLowerCase();

        List<String> keywords =
            new List<String>{
                'ceo',
                'cfo',
                'cto',
                'cio',
                'chief',
                'vp',
                'vice president',
                'director',
                'head',
                'owner',
                'decision maker'
            };

        for (String keyword : keywords) {

            if (combined.contains(keyword)) {
                return true;
            }
        }

        return false;
    }


    private static void calculateHealth(
        DealContext context
    ) {

        Integer score = 100;

        List<String> risks =
            new List<String>();

        List<String> positives =
            new List<String>();


        /*
         * Activity risk
         */

        if (context.daysSinceLastActivity >= 30) {

            score -= 30;

            risks.add(
                'No meaningful activity in the last 30 days.'
            );

        } else if (
            context.daysSinceLastActivity >= 14
        ) {

            score -= 20;

            risks.add(
                'No meaningful activity in the last 14 days.'
            );

        } else if (
            context.daysSinceLastActivity >= 7
        ) {

            score -= 10;

            risks.add(
                'Activity is slowing down.'
            );

        } else {

            positives.add(
                'Recent activity indicates engagement.'
            );
        }


        /*
         * Stakeholder risk
         */

        if (context.contactCount == 0) {

            score -= 20;

            risks.add(
                'No Opportunity Contact Roles are associated with the deal.'
            );

        } else if (
            !context.decisionMakerPresent
        ) {

            score -= 15;

            risks.add(
                'No obvious decision maker has been identified.'
            );

        } else {

            positives.add(
                'Decision-maker coverage detected.'
            );
        }


        /*
         * Task risk
         */

        if (context.overdueTaskCount > 0) {

            Integer penalty =
                Math.min(
                    context.overdueTaskCount * 5,
                    20
                );

            score -= penalty;

            risks.add(
                String.valueOf(
                    context.overdueTaskCount
                ) +
                ' overdue task(s) require attention.'
            );

        } else {

            positives.add(
                'No overdue tasks detected.'
            );
        }


        /*
         * Close-date risk
         */

        if (context.closeDate != null) {

            Integer daysToClose =
                Date.today().daysBetween(
                    context.closeDate
                );

            if (
                daysToClose >= 0 &&
                daysToClose <= 7
            ) {

                score -= 15;

                risks.add(
                    'Close date is within 7 days.'
                );
            }
        }


        /*
         * Clamp score.
         */

        if (score < 0) {
            score = 0;
        }

        if (score > 100) {
            score = 100;
        }

        context.healthScore = score;

        context.riskSignals = risks;

        context.positiveSignals = positives;


        if (score >= 80) {

            context.healthStatus =
                'Healthy';

        } else if (score >= 60) {

            context.healthStatus =
                'At Risk';

        } else {

            context.healthStatus =
                'Critical';
        }
    }
}