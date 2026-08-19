import { LightningElement, api } from 'lwc';
import summarizeAccountMergeImpact from '@salesforce/apex/ChildRelationshipService.summarizeAccountMergeImpact';
import mergeRecords from '@salesforce/apex/MergeExecutionService.mergeRecords';

export default class MergeWizard extends LightningElement {
    @api objectApiName = 'Account';
    @api masterRecordId;
    @api duplicateRecordIds = [];

    impact;
    message;

    objectOptions = [
        { label: 'Account', value: 'Account' },
        { label: 'Contact', value: 'Contact' },
        { label: 'Lead', value: 'Lead' }
    ];

    get duplicateIdsText() {
        return Array.isArray(this.duplicateRecordIds) ? this.duplicateRecordIds.join(',') : this.duplicateRecordIds;
    }

    handleObject(event) { this.objectApiName = event.detail.value; }
    handleMaster(event) { this.masterRecordId = event.detail.value; }
    handleDuplicates(event) {
        this.duplicateRecordIds = event.detail.value.split(',').map((item) => item.trim()).filter(Boolean);
    }

    async previewImpact() {
        if (this.objectApiName !== 'Account') {
            this.message = 'Impact preview is currently available for Account merges.';
            return;
        }
        this.impact = await summarizeAccountMergeImpact({
            accountIds: [this.masterRecordId].concat(this.duplicateRecordIds)
        });
    }

    async executeMerge() {
        const result = await mergeRecords({
            request: {
                objectApiName: this.objectApiName,
                masterRecordId: this.masterRecordId,
                duplicateRecordIds: this.duplicateRecordIds
            }
        });
        this.message = `${result.mergeId}: ${result.message}`;
    }
}