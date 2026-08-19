import { LightningElement, api } from 'lwc';
import parseContentVersion from '@salesforce/apex/CsvParserService.parseContentVersion';
import describeCreateableFields from '@salesforce/apex/BulkImportOrchestrator.describeCreateableFields';
import startImport from '@salesforce/apex/BulkImportOrchestrator.startImport';

export default class FieldMapper extends LightningElement {
    @api contentVersionId;
    @api objectApiName = 'Account';

    headers = [];
    fieldOptions = [];
    mappings = {};
    summary;

    objectOptions = [
        { label: 'Account', value: 'Account' },
        { label: 'Contact', value: 'Contact' },
        { label: 'Lead', value: 'Lead' }
    ];

    get mappingRows() {
        return this.headers.map((header) => ({
            header,
            value: this.mappings[header] || ''
        }));
    }

    get hasHeaders() {
        return this.headers.length > 0;
    }

    connectedCallback() {
        this.load();
    }

    async load() {
        const parsed = await parseContentVersion({ contentVersionId: this.contentVersionId });
        this.headers = parsed.headers || [];
        await this.loadFields();
        this.summary = `${parsed.rowCount || 0} rows ready for mapping.`;
    }

    async loadFields() {
        const fields = await describeCreateableFields({ objectApiName: this.objectApiName });
        this.fieldOptions = [{ label: 'Ignore', value: '' }].concat(
            fields.map((field) => ({ label: field, value: field }))
        );
        this.mappings = {};
        this.headers.forEach((header) => {
            this.mappings[header] = fields.includes(header) ? header : '';
        });
    }

    async handleObjectChange(event) {
        this.objectApiName = event.detail.value;
        this.dispatchEvent(new CustomEvent('objectchange', { detail: { objectApiName: this.objectApiName } }));
        await this.loadFields();
    }

    handleMappingChange(event) {
        this.mappings = {
            ...this.mappings,
            [event.target.dataset.header]: event.detail.value
        };
    }

    async analyzeRisk() {
        const result = await this.runImport(true);
        this.summary = `${result.status}: ${result.totalRows} rows analyzed. ${result.errors?.length || 0} warnings.`;
    }

    async startImport() {
        const result = await this.runImport(false);
        this.summary = `${result.status}: ${result.successRows} succeeded, ${result.failedRows} failed.`;
        this.dispatchEvent(new CustomEvent('importstarted', { detail: { importId: result.importId } }));
    }

    runImport(dryRun) {
        return startImport({
            request: {
                contentVersionId: this.contentVersionId,
                objectApiName: this.objectApiName,
                fieldMappingJson: JSON.stringify(this.mappings),
                dryRun
            }
        });
    }
}