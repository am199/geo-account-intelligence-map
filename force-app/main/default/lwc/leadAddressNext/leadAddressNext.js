import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class LeadAddressNext extends LightningElement {
    _recordId;
    urlRecordId;
    hasInitialized = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this.tryInit();
    }

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        this.urlRecordId = pageRef?.state?.c__recordId;
        this.tryInit();
    }

    tryInit() {
        const effectiveRecordId = this._recordId || this.urlRecordId;
        if (!effectiveRecordId || this.hasInitialized) {
            return;
        }
        this.hasInitialized = true;
        this.init(effectiveRecordId);
    }

    init(recordId) {
        // Call Apex here after recordId is ready, for example:
        // getLeadData({ leadId: recordId })
    }
}
