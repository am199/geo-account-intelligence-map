import { LightningElement, api } from 'lwc';
import { subscribe, onError } from 'lightning/empApi';

export default class ImportProgressTracker extends LightningElement {
    @api importId;
    events = [];
    subscribed = false;

    connectedCallback() {
        onError((error) => {
            this.appendEvent('EMP API Error', JSON.stringify(error));
        });
    }

    subscribe() {
        if (this.subscribed) {
            return;
        }
        subscribe('/event/Import_Progress__e', -1, (message) => this.handleProgress(message));
        subscribe('/event/Import_Error__e', -1, (message) => this.handleError(message));
        this.subscribed = true;
        this.appendEvent('Subscribed', 'Listening for import progress and failed row events.');
    }

    handleProgress(message) {
        const payload = message.data.payload;
        if (this.importId && payload.Import_Id__c !== this.importId) {
            return;
        }
        this.appendEvent(payload.Status__c, payload.Message__c);
    }

    handleError(message) {
        const payload = message.data.payload;
        if (this.importId && payload.Import_Id__c !== this.importId) {
            return;
        }
        this.appendEvent('Failed row ' + payload.Row_Number__c, payload.Error_Message__c);
    }

    appendEvent(status, message) {
        this.events = [
            { id: Date.now() + Math.random(), status, message },
            ...this.events
        ].slice(0, 20);
    }
}