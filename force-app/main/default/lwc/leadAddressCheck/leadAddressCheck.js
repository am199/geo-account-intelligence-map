import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import getLeadAddress from '@salesforce/apex/LeadAddressCheckController.getLeadAddress';

const FIELDS = ['Lead.Id'];

export default class LeadAddressCheck extends NavigationMixin(LightningElement) {
    @api recordId;

    isLoading = true;
    hasError = false;
    isValid = false;
    hasChecked = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredLead({ error, data }) {
        if (error) {
            this.hasError = true;
            this.isLoading = false;
            this.showError('Unable to read Lead record.');
            return;
        }

        if (!data || this.hasChecked) {
            return;
        }

        this.hasChecked = true;
        this.checkAddress(this.recordId);
    }

    async checkAddress(leadId) {
        this.isLoading = true;

        try {
            const data = await getLeadAddress({ recordId: leadId });

            const street = data?.street;
            const city = data?.city;
            const state = data?.state;
            const postal = data?.postalCode;
            const country = data?.country;

            const allFilled = Boolean(street && city && state && postal && country);

            if (!allFilled) {
                this.hasError = true;
                this.showError(
                    'Please fill Street, City, State, Postal Code, and Country on the Lead before continuing.'
                );
                return;
            }

            this.isValid = true;
            this.navigateToNext();
        } catch (err) {
            this.hasError = true;
            this.showError('Unable to read Lead address fields.');
        } finally {
            this.isLoading = false;
        }
    }

    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Missing Address Fields',
                message,
                variant: 'error'
            })
        );
    }

    navigateToNext() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: {
                componentName: 'c__LeadAddressNext'
            },
            state: {
                c__recordId: this.recordId
            }
        });

        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
