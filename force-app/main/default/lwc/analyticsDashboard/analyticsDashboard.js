import { LightningElement } from 'lwc';
import getOperationalMetrics from '@salesforce/apex/AnalyticsAggregationService.getOperationalMetrics';

export default class AnalyticsDashboard extends LightningElement {
    metrics = [];

    connectedCallback() {
        this.loadMetrics();
    }

    async loadMetrics() {
        this.metrics = await getOperationalMetrics();
    }
}