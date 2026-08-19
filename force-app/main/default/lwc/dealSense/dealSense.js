import {
    LightningElement,
    api,
    wire
} from 'lwc';

import getDealHealth
    from '@salesforce/apex/DealHealthController.getDealHealth';

import {
    open,
    execute
} from 'lightning/accApi';

import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';


export default class DealSense
    extends LightningElement {

    @api recordId;

    healthScore = 0;

    healthStatus = '';

    daysSinceLastActivity = 0;

    contactCount = 0;

    openTaskCount = 0;

    overdueTaskCount = 0;

    riskSignals = [];

    positiveSignals = [];

    loading = false;


    @wire(
        getDealHealth,
        {
            opportunityId: '$recordId'
        }
    )
    wiredDealHealth({
        data,
        error
    }) {

        if (data) {

            this.healthScore =
                data.healthScore ?? 0;

            this.healthStatus =
                data.healthStatus ?? 'Unknown';

            this.daysSinceLastActivity =
                data.daysSinceLastActivity ?? 0;

            this.contactCount =
                data.contactCount ?? 0;

            this.openTaskCount =
                data.openTaskCount ?? 0;

            this.overdueTaskCount =
                data.overdueTaskCount ?? 0;

            this.riskSignals =
                data.riskSignals ?? [];

            this.positiveSignals =
                data.positiveSignals ?? [];

        } else if (error) {

            this.showToast(
                'Error',
                this.reduceError(error),
                'error'
            );
        }
    }


    get hasRisks() {

        return (
            this.riskSignals &&
            this.riskSignals.length > 0
        );
    }


    get hasPositives() {

        return (
            this.positiveSignals &&
            this.positiveSignals.length > 0
        );
    }


    get activityLabel() {

        if (
            this.daysSinceLastActivity === 999
        ) {
            return 'Never';
        }

        if (
            this.daysSinceLastActivity === 0
        ) {
            return 'Today';
        }

        if (
            this.daysSinceLastActivity === 1
        ) {
            return '1 day ago';
        }

        return (
            this.daysSinceLastActivity +
            ' days ago'
        );
    }


    get healthStatusClass() {

        switch (
            this.healthStatus
        ) {

            case 'Healthy':
                return 'status healthy';

            case 'At Risk':
                return 'status risk';

            case 'Critical':
                return 'status critical';

            default:
                return 'status';
        }
    }


    get healthDescription() {

        if (
            this.healthScore >= 80
        ) {
            return 'This deal shows strong engagement signals.';
        }

        if (
            this.healthScore >= 60
        ) {
            return 'This deal has signals that deserve attention.';
        }

        return 'This deal requires immediate attention.';
    }


    async handleCoachMe() {

        this.loading = true;

        try {

            /*
             * Open the native Agentforce panel.
             */

            await open();


            /*
             * Give Agentforce the Opportunity context.
             *
             * The agent instructions will tell it to
             * use the Get Deal Context action.
             */

            const utterance =
                `Coach me on Opportunity ${this.recordId}. 
                 Analyze the deal health, identify the top risks,
                 and recommend the three most important next actions.
                 Do not create tasks unless I explicitly approve them.`;


            await execute(
                utterance
            );


        } catch (error) {

            this.showToast(
                'Unable to open Deal Coach',
                this.reduceError(error),
                'error'
            );

        } finally {

            this.loading = false;
        }
    }


    showToast(
        title,
        message,
        variant
    ) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }


    reduceError(error) {

        if (!error) {
            return 'Unknown error';
        }

        if (
            Array.isArray(error.body)
        ) {

            return error.body
                .map(
                    item => item.message
                )
                .join(', ');
        }

        if (
            error.body &&
            error.body.message
        ) {

            return error.body.message;
        }

        if (
            error.message
        ) {

            return error.message;
        }

        return 'Something went wrong.';
    }
}