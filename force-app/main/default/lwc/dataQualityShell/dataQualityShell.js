import { LightningElement } from 'lwc';

export default class DataQualityShell extends LightningElement {
    contentVersionId;
    objectApiName = 'Account';
    importId;
    selectedDuplicate = {};

    handleFileUploaded(event) {
        this.contentVersionId = event.detail.contentVersionId;
    }

    handleObjectChange(event) {
        this.objectApiName = event.detail.objectApiName;
    }

    handleImportStarted(event) {
        this.importId = event.detail.importId;
    }

    handleDuplicateSelected(event) {
        this.selectedDuplicate = event.detail;
    }
}