public with sharing class DealTaskAction {

    public class Request {

        @InvocableVariable(
            required=true
            description='Opportunity Id associated with the task.'
        )
        public Id opportunityId;

        @InvocableVariable(
            required=true
            description='Subject of the recommended task.'
        )
        public String subject;

        @InvocableVariable(
            description='Detailed description of the task.'
        )
        public String description;

        @InvocableVariable(
            required=true
            description='Due date for the task.'
        )
        public Date dueDate;

        @InvocableVariable(
            description='Task priority. Valid values are High, Normal, or Low.'
        )
        public String priority;
    }


    public class Response {

        @InvocableVariable
        public Id taskId;

        @InvocableVariable
        public String message;
    }


    @InvocableMethod(
        label='Create Deal Coaching Task'
        description='Creates a follow-up Task on an Opportunity after the sales representative approves a recommended action.'
    )
    public static List<Response> execute(
        List<Request> requests
    ) {

        List<Task> tasks =
            new List<Task>();

        for (Request request : requests) {

            if (
                request.opportunityId == null
            ) {
                continue;
            }

            Task task = new Task();

            task.WhatId =
                request.opportunityId;

            task.Subject =
                String.isBlank(request.subject)
                    ? 'Deal Coach Follow-up'
                    : request.subject;

            task.Description =
                request.description;

            task.ActivityDate =
                request.dueDate != null
                    ? request.dueDate
                    : Date.today().addDays(3);

            task.Priority =
                normalizePriority(
                    request.priority
                );

            task.Status =
                'Not Started';

            tasks.add(task);
        }


        if (!tasks.isEmpty()) {

            insert as user tasks;
        }


        List<Response> responses =
            new List<Response>();

        for (Task task : tasks) {

            Response response =
                new Response();

            response.taskId =
                task.Id;

            response.message =
                'Deal coaching task created successfully.';

            responses.add(response);
        }

        return responses;
    }


    private static String normalizePriority(
        String priority
    ) {

        if (
            priority == 'High' ||
            priority == 'Low'
        ) {
            return priority;
        }

        return 'Normal';
    }
}