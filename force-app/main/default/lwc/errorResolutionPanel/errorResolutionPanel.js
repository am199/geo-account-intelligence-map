import { LightningElement } from 'lwc';
import analyzeError from '@salesforce/apex/ImportErrorAnalyzer.analyze';

export default class ErrorResolutionPanel extends LightningElement {
    errorMessage = '';
    insight;

    handleError(event) {
        this.errorMessage = event.detail.value;
    }

    async analyze() {
        this.insight = await analyzeError({ errorMessage: this.errorMessage });
    }
}