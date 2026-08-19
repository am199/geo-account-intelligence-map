public with sharing class DealContextAction {

    // ============================================================
    // INPUT
    // ============================================================

    public class Request {

        @InvocableVariable(
            label='Opportunity Id'
            description='The Salesforce Opportunity Id for the deal that should be analyzed.'
            required=true
        )
        public Id opportunityId;
    }


    // ============================================================
    // OUTPUT
    // ============================================================

    public class Response {

        @InvocableVariable(
            label='Deal Context'
            description='Salesforce CRM information about the Opportunity, Account, stakeholders, tasks, activity, risks, and positive signals.'
        )
        public String dealContext;
    }


    // ============================================================
    // INVOCABLE METHOD
    // ============================================================

    @InvocableMethod(
        label='Get Deal Context'
        description='Retrieves Opportunity, Account, Opportunity Contact Roles, Contacts, open Tasks, overdue Tasks, and recent Events for deal coaching.'
    )
    public static List<Response> getDealContext(
        List<Request> requests
    ) {

        List<Response> results = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }


        // ========================================================
        // COLLECT OPPORTUNITY IDS
        // ========================================================

        Set<Id> opportunityIds = new Set<Id>();

        for (Request request : requests) {

            if (
                request != null &&
                request.opportunityId != null
            ) {
                opportunityIds.add(request.opportunityId);
            }
        }


        // ========================================================
        // HANDLE MISSING OPPORTUNITY ID
        // ========================================================

        if (opportunityIds.isEmpty()) {

            for (Request request : requests) {

                Response response = new Response();

                response.dealContext =
                    'No Opportunity Id was provided.';

                results.add(response);
            }

            return results;
        }


        // ========================================================
        // 1. OPPORTUNITY + ACCOUNT
        // ========================================================

        Map<Id, Opportunity> opportunities =
            new Map<Id, Opportunity>([
                SELECT
                    Id,
                    Name,
                    StageName,
                    Amount,
                    CloseDate,
                    Probability,
                    ForecastCategoryName,
                    Type,
                    LeadSource,
                    Description,
                    OwnerId,
                    Owner.Name,
                    AccountId,
                    Account.Name,
                    Account.Industry,
                    Account.Type
                FROM Opportunity
                WHERE Id IN :opportunityIds
            ]);


        // ========================================================
        // 2. OPPORTUNITY CONTACT ROLES
        // ========================================================

        Map<Id, List<OpportunityContactRole>> rolesByOpportunity =
            new Map<Id, List<OpportunityContactRole>>();

        for (OpportunityContactRole role : [

            SELECT
                Id,
                OpportunityId,
                ContactId,
                Contact.Name,
                Contact.Email,
                Contact.Title,
                Contact.Department,
                Role,
                IsPrimary

            FROM OpportunityContactRole

            WHERE OpportunityId IN :opportunityIds
        ]) {

            if (
                !rolesByOpportunity.containsKey(
                    role.OpportunityId
                )
            ) {

                rolesByOpportunity.put(
                    role.OpportunityId,
                    new List<OpportunityContactRole>()
                );
            }

            rolesByOpportunity
                .get(role.OpportunityId)
                .add(role);
        }


        // ========================================================
        // 3. TASKS
        // ========================================================

        Map<Id, List<Task>> tasksByOpportunity =
            new Map<Id, List<Task>>();

        for (Task task : [

            SELECT
                Id,
                Subject,
                Status,
                Priority,
                ActivityDate,
                Description,
                Owner.Name,
                CreatedDate

            FROM Task

            WHERE WhatId IN :opportunityIds

            ORDER BY ActivityDate ASC NULLS LAST
        ]) {

            if (
                !tasksByOpportunity.containsKey(
                    task.WhatId
                )
            ) {

                tasksByOpportunity.put(
                    task.WhatId,
                    new List<Task>()
                );
            }

            tasksByOpportunity
                .get(task.WhatId)
                .add(task);
        }


        // ========================================================
        // 4. EVENTS / RECENT ACTIVITY
        // ========================================================

        Map<Id, List<Event>> eventsByOpportunity =
            new Map<Id, List<Event>>();

        for (Event eventRecord : [

            SELECT
                Id,
                Subject,
                StartDateTime,
                EndDateTime,
                Description,
                Owner.Name

            FROM Event

            WHERE WhatId IN :opportunityIds

            ORDER BY StartDateTime DESC
        ]) {

            if (
                !eventsByOpportunity.containsKey(
                    eventRecord.WhatId
                )
            ) {

                eventsByOpportunity.put(
                    eventRecord.WhatId,
                    new List<Event>()
                );
            }

            eventsByOpportunity
                .get(eventRecord.WhatId)
                .add(eventRecord);
        }


        // ========================================================
        // 5. BUILD DEAL CONTEXT
        // ========================================================

        for (Request request : requests) {

            Response response = new Response();


            // ----------------------------------------------------
            // Missing ID
            // ----------------------------------------------------

            if (
                request == null ||
                request.opportunityId == null
            ) {

                response.dealContext =
                    'No Opportunity Id was provided.';

                results.add(response);

                continue;
            }


            // ----------------------------------------------------
            // Opportunity not found
            // ----------------------------------------------------

            Opportunity opp =
                opportunities.get(
                    request.opportunityId
                );

            if (opp == null) {

                response.dealContext =
                    'Opportunity not found for Id: ' +
                    String.valueOf(
                        request.opportunityId
                    );

                results.add(response);

                continue;
            }


            String context = '';


            // ====================================================
            // OPPORTUNITY
            // ====================================================

            context +=
                '=== OPPORTUNITY ===\n';

            context +=
                'Opportunity Id: ' +
                String.valueOf(opp.Id) +
                '\n';

            context +=
                'Name: ' +
                String.valueOf(opp.Name) +
                '\n';

            context +=
                'Stage: ' +
                String.valueOf(opp.StageName) +
                '\n';

            context +=
                'Amount: ' +
                String.valueOf(opp.Amount) +
                '\n';

            context +=
                'Close Date: ' +
                String.valueOf(opp.CloseDate) +
                '\n';

            context +=
                'Probability: ' +
                String.valueOf(opp.Probability) +
                '%\n';

            context +=
                'Forecast Category: ' +
                String.valueOf(
                    opp.ForecastCategoryName
                ) +
                '\n';

            context +=
                'Type: ' +
                String.valueOf(opp.Type) +
                '\n';

            context +=
                'Lead Source: ' +
                String.valueOf(opp.LeadSource) +
                '\n';

            context +=
                'Owner: ' +
                String.valueOf(opp.Owner.Name) +
                '\n';


            // ====================================================
            // ACCOUNT
            // ====================================================

            context +=
                '\n=== ACCOUNT ===\n';

            if (opp.Account != null) {

                context +=
                    'Account: ' +
                    String.valueOf(
                        opp.Account.Name
                    ) +
                    '\n';

                context +=
                    'Industry: ' +
                    String.valueOf(
                        opp.Account.Industry
                    ) +
                    '\n';

                context +=
                    'Account Type: ' +
                    String.valueOf(
                        opp.Account.Type
                    ) +
                    '\n';

            } else {

                context +=
                    'No Account associated.\n';
            }


            // ====================================================
            // STAKEHOLDERS
            // ====================================================

            context +=
                '\n=== STAKEHOLDERS ===\n';

            List<OpportunityContactRole> roles =
                rolesByOpportunity.get(opp.Id);

            if (
                roles == null ||
                roles.isEmpty()
            ) {

                context +=
                    'No Opportunity Contact Roles found.\n';

            } else {

                for (
                    OpportunityContactRole role :
                    roles
                ) {

                    context +=
                        'Contact: ' +
                        String.valueOf(
                            role.Contact.Name
                        ) +
                        ' | Title: ' +
                        String.valueOf(
                            role.Contact.Title
                        ) +
                        ' | Department: ' +
                        String.valueOf(
                            role.Contact.Department
                        ) +
                        ' | Role: ' +
                        String.valueOf(
                            role.Role
                        ) +
                        ' | Primary: ' +
                        String.valueOf(
                            role.IsPrimary
                        ) +
                        '\n';
                }
            }


            // ====================================================
            // TASKS
            // ====================================================

            context +=
                '\n=== TASKS ===\n';

            List<Task> tasks =
                tasksByOpportunity.get(opp.Id);

            Integer openTaskCount = 0;
            Integer overdueTaskCount = 0;

            if (
                tasks == null ||
                tasks.isEmpty()
            ) {

                context +=
                    'No Tasks found.\n';

            } else {

                for (Task task : tasks) {

                    Boolean isOpen =
                        task.Status != 'Completed';

                    Boolean isOverdue =
                        isOpen &&
                        task.ActivityDate != null &&
                        task.ActivityDate < Date.today();

                    if (isOpen) {
                        openTaskCount++;
                    }

                    if (isOverdue) {
                        overdueTaskCount++;
                    }

                    context +=
                        'Subject: ' +
                        String.valueOf(
                            task.Subject
                        ) +
                        ' | Status: ' +
                        String.valueOf(
                            task.Status
                        ) +
                        ' | Priority: ' +
                        String.valueOf(
                            task.Priority
                        ) +
                        ' | Due: ' +
                        String.valueOf(
                            task.ActivityDate
                        ) +
                        ' | Overdue: ' +
                        String.valueOf(
                            isOverdue
                        ) +
                        '\n';
                }
            }

            context +=
                'Open Task Count: ' +
                String.valueOf(
                    openTaskCount
                ) +
                '\n';

            context +=
                'Overdue Task Count: ' +
                String.valueOf(
                    overdueTaskCount
                ) +
                '\n';


            // ====================================================
            // EVENTS
            // ====================================================

            context +=
                '\n=== RECENT EVENTS ===\n';

            List<Event> events =
                eventsByOpportunity.get(opp.Id);

            if (
                events == null ||
                events.isEmpty()
            ) {

                context +=
                    'No Events found.\n';

            } else {

                Integer eventCount = 0;

                for (
                    Event eventRecord :
                    events
                ) {

                    if (eventCount >= 10) {
                        break;
                    }

                    context +=
                        'Subject: ' +
                        String.valueOf(
                            eventRecord.Subject
                        ) +
                        ' | Start: ' +
                        String.valueOf(
                            eventRecord.StartDateTime
                        ) +
                        '\n';

                    eventCount++;
                }
            }


            // ====================================================
            // DEAL SIGNALS
            // ====================================================

            context +=
                '\n=== DEAL SIGNALS ===\n';


            // Close date risk

            if (
                opp.CloseDate != null &&
                opp.CloseDate < Date.today()
            ) {

                context +=
                    'RISK: Close date has passed.\n';

            } else if (
                opp.CloseDate != null &&
                opp.CloseDate <=
                    Date.today().addDays(14)
            ) {

                context +=
                    'RISK: Opportunity closes within 14 days.\n';
            }


            // Overdue tasks

            if (overdueTaskCount > 0) {

                context +=
                    'RISK: There are ' +
                    String.valueOf(
                        overdueTaskCount
                    ) +
                    ' overdue Tasks.\n';
            }


            // Stakeholder coverage

            if (
                roles == null ||
                roles.isEmpty()
            ) {

                context +=
                    'RISK: No Opportunity Contact Roles are recorded.\n';

            } else {

                context +=
                    'POSITIVE: Opportunity has ' +
                    String.valueOf(
                        roles.size()
                    ) +
                    ' stakeholder(s) recorded.\n';
            }


            // ====================================================
            // SUMMARY COUNTS
            // ====================================================

            context +=
                '\n=== SUMMARY ===\n';

            context +=
                'Open Tasks: ' +
                String.valueOf(
                    openTaskCount
                ) +
                '\n';

            context +=
                'Overdue Tasks: ' +
                String.valueOf(
                    overdueTaskCount
                ) +
                '\n';

            context +=
                'Stakeholders: ' +
                String.valueOf(
                    roles == null
                        ? 0
                        : roles.size()
                ) +
                '\n';


            // ====================================================
            // RETURN
            // ====================================================

            response.dealContext = context;

            results.add(response);
        }

        return results;
    }
}