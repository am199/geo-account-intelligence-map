import { LightningElement } from 'lwc';
import investigate from '@salesforce/apex/AgentInsightService.investigate';

export default class AiInvestigatorPanel extends LightningElement {
    question = '';
    objectApiName = 'Account';
    recordId;
    response;

    objectOptions = [
        { label: 'Account', value: 'Account' },
        { label: 'Contact', value: 'Contact' },
        { label: 'Lead', value: 'Lead' }
    ];

    handleQuestion(event) { this.question = event.detail.value; }
    handleObject(event) { this.objectApiName = event.detail.value; }
    handleRecord(event) { this.recordId = event.detail.value; }

    async investigate() {
        this.response = await investigate({
            request: {
                question: this.question,
                objectApiName: this.objectApiName,
                recordId: this.recordId
            }
        });
    }
}