public with sharing class ProposalPDFController {

    public Opportunity opportunity { get; private set; }
    public Account account { get; private set; }
    public Contact contact { get; private set; }

    public List<OpportunityLineItem> lineItems {
        get;
        private set;
    }

    public String documentTitle {
        get;
        private set;
    }

    public ProposalPDFController() {

        Id opportunityId =
            ApexPages.currentPage()
                .getParameters()
                .get('id');

        String template =
            ApexPages.currentPage()
                .getParameters()
                .get('template');

        if (opportunityId == null) {
            throw new ProposalException(
                'Opportunity Id is required.'
            );
        }

        loadData(opportunityId);

        documentTitle =
            String.isBlank(template)
                ? 'Sales Proposal'
                : template;
    }

    private void loadData(Id opportunityId) {

        opportunity = [
            SELECT
                Id,
                Name,
                StageName,
                CloseDate,
                Amount,
                Probability,
                AccountId,
                Account.Name,
                Account.BillingStreet,
                Account.BillingCity,
                Account.BillingState,
                Account.BillingPostalCode,
                Account.BillingCountry
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        account = opportunity.Account;

        List<Contact> contacts = [
            SELECT
                Id,
                Name,
                Email,
                Phone
            FROM Contact
            WHERE AccountId = :opportunity.AccountId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (!contacts.isEmpty()) {
            contact = contacts[0];
        } else {
            contact = new Contact(
        LastName = 'Customer Contact'
    );
        }

        lineItems = [
            SELECT
                Id,
                Quantity,
                UnitPrice,
                TotalPrice,
                PricebookEntry.Product2.Name,
                PricebookEntry.Product2.Description
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
        ];
    }

    public class ProposalException extends Exception {}
}
