import { LightningElement } from 'lwc';
import findAccountDuplicates from '@salesforce/apex/DuplicateDetectionService.findAccountDuplicates';
import findContactDuplicates from '@salesforce/apex/DuplicateDetectionService.findContactDuplicates';

export default class DuplicateWorkbench extends LightningElement {
    objectType = 'Account';
    accountName = '';
    website = '';
    firstName = '';
    lastName = '';
    email = '';
    candidates = [];

    objectOptions = [
        { label: 'Account', value: 'Account' },
        { label: 'Contact', value: 'Contact' }
    ];

    columns = [
        { label: 'Name', fieldName: 'displayName' },
        { label: 'Secondary', fieldName: 'secondaryValue' },
        { label: 'Score', fieldName: 'score', type: 'number' },
        { label: 'Reason', fieldName: 'reason' }
    ];

    get isAccount() {
        return this.objectType === 'Account';
    }

    handleObjectType(event) { this.objectType = event.detail.value; }
    handleAccountName(event) { this.accountName = event.detail.value; }
    handleWebsite(event) { this.website = event.detail.value; }
    handleFirstName(event) { this.firstName = event.detail.value; }
    handleLastName(event) { this.lastName = event.detail.value; }
    handleEmail(event) { this.email = event.detail.value; }

    async findDuplicates() {
        this.candidates = this.isAccount
            ? await findAccountDuplicates({ accountName: this.accountName, website: this.website, limitSize: 25 })
            : await findContactDuplicates({ firstName: this.firstName, lastName: this.lastName, email: this.email, limitSize: 25 });
    }

    handleSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length < 2) {
            return;
        }
        this.dispatchEvent(new CustomEvent('selected', {
            detail: {
                objectApiName: this.objectType,
                masterRecordId: selectedRows[0].recordId,
                duplicateRecordIds: selectedRows.slice(1).map((row) => row.recordId)
            }
        }));
    }
}