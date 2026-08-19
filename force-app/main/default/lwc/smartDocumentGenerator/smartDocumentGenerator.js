import {
    LightningElement,
    api,
    wire
} from 'lwc';

import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';

import getTemplates
    from '@salesforce/apex/DocumentTemplateService.getTemplates';

import generateDocument
    from '@salesforce/apex/SmartDocumentService.generateDocument';

import getHistory
    from '@salesforce/apex/SmartDocumentHistoryService.getHistory';

import sendDocument
    from '@salesforce/apex/SmartDocumentEmailService.sendDocument';

import deleteDocument
    from '@salesforce/apex/SmartDocumentHistoryService.deleteDocument';

import {
    refreshApex
} from '@salesforce/apex';


export default class SmartDocumentGenerator
    extends LightningElement {


    // ---------------------------------------------------------
    // Salesforce Record Id
    // ---------------------------------------------------------

    @api recordId;


    // ---------------------------------------------------------
    // Template State
    // ---------------------------------------------------------

    templateOptions = [];

    selectedTemplate;

    selectedTemplateDescription;


    // ---------------------------------------------------------
    // Document State
    // ---------------------------------------------------------

    generatedDocument;

    history = [];

    wiredHistoryResult;


    // ---------------------------------------------------------
    // UI State
    // ---------------------------------------------------------

    isGenerating = false;

    isSendingEmail = false;

    showEmailModal = false;

    recipientEmail = '';


    // ---------------------------------------------------------
    // Load Templates
    // ---------------------------------------------------------

    @wire(getTemplates)
    wiredTemplates({
        data,
        error
    }) {

        if (data) {

            this.templateOptions =
                data.map(template => {

                    return {
                        label: template.label,
                        value: template.value,
                        description: template.description
                    };

                });


            if (
                this.templateOptions.length > 0 &&
                !this.selectedTemplate
            ) {

                this.selectedTemplate =
                    this.templateOptions[0].value;

                this.selectedTemplateDescription =
                    this.templateOptions[0].description;
            }

        } else if (error) {

            this.showError(error);
        }
    }


    // ---------------------------------------------------------
    // Load Document History
    // ---------------------------------------------------------

    @wire(getHistory, {
        opportunityId: '$recordId'
    })
    wiredHistory(result) {

        this.wiredHistoryResult = result;

        if (result.data) {

            this.history = result.data;

        } else if (result.error) {

            this.showError(result.error);

            this.history = [];
        }
    }


    // ---------------------------------------------------------
    // Template Selection
    // ---------------------------------------------------------

    handleTemplateChange(event) {

        this.selectedTemplate =
            event.detail.value;


        const selected =
            this.templateOptions.find(
                template =>
                    template.value ===
                    this.selectedTemplate
            );


        this.selectedTemplateDescription =
            selected
                ? selected.description
                : null;
    }


    // ---------------------------------------------------------
    // Generate Button State
    // ---------------------------------------------------------

    get generateDisabled() {

        return (
            this.isGenerating ||
            !this.selectedTemplate ||
            !this.recordId
        );
    }


    // ---------------------------------------------------------
    // Generate Document
    // ---------------------------------------------------------

    async handleGenerate() {

        if (!this.recordId) {

            this.showToast(
                'Error',
                'This component must be placed on an Opportunity record page.',
                'error'
            );

            return;
        }


        if (!this.selectedTemplate) {

            this.showToast(
                'Error',
                'Please select a document template.',
                'error'
            );

            return;
        }


        this.isGenerating = true;


        try {

            const result =
                await generateDocument({

                    opportunityId:
                        this.recordId,

                    templateDeveloperName:
                        this.selectedTemplate

                });


            this.generatedDocument =
                result;


            // Refresh history immediately after generation
           // await this.refreshHistory();


            this.showToast(
                'Success',
                'Proposal generated successfully.',
                'success'
            );


        } catch (error) {

            this.showError(error);

        } finally {

            this.isGenerating = false;
        }
    }


    // ---------------------------------------------------------
    // PDF Preview URL
    // ---------------------------------------------------------

    get previewUrl() {

        if (
            !this.generatedDocument ||
            !this.generatedDocument.downloadUrl
        ) {

            return null;
        }


        return this.generatedDocument.downloadUrl;
    }


    // ---------------------------------------------------------
    // Open / Download Latest Document
    // ---------------------------------------------------------

    async handleDownload(event) {

        try {

            const action =
                event.currentTarget.dataset.action;


            if (!this.generatedDocument) {

                this.showToast(
                    'Error',
                    'No generated document is available.',
                    'error'
                );

                return;
            }


            // -------------------------------------------------
            // Get ContentDocumentId
            // -------------------------------------------------

            const contentDocumentId =
                this.generatedDocument.contentDocumentId ||
                this.generatedDocument.ContentDocumentId ||
                this.generatedDocument.documentId ||
                this.generatedDocument.contentDocumentID;


            if (!contentDocumentId) {

                console.error(
                    'ContentDocumentId is missing:',
                    JSON.stringify(this.generatedDocument)
                );


                this.showToast(
                    'Error',
                    'The generated document ID is missing.',
                    'error'
                );

                return;
            }


            // -------------------------------------------------
            // OPEN PDF
            // -------------------------------------------------

            if (action === 'open') {

                const previewUrl =
                    `/lightning/r/ContentDocument/${contentDocumentId}/view`;


                window.open(
                    previewUrl,
                    '_blank'
                );


                // Refresh history UI
                if (this.wiredHistoryResult) {

                    await refreshApex(
                        this.wiredHistoryResult
                    );
                }


                return;
            }


            // -------------------------------------------------
            // DOWNLOAD PDF
            // -------------------------------------------------

            if (action === 'download') {

                const downloadUrl =
                    `/sfc/servlet.shepherd/document/download/${contentDocumentId}`;


                const link =
                    document.createElement('a');


                link.href =
                    downloadUrl;


                link.download =
                    this.generatedDocument.fileName ||
                    'Proposal.pdf';


                link.target =
                    '_self';


                document.body.appendChild(
                    link
                );


                link.click();


                document.body.removeChild(
                    link
                );

await this.refreshHistory(); 


                return;
            }


        } catch (error) {

            console.error(
                'PDF action error:',
                error
            );


            this.showToast(
                'Error',
                error?.message ||
                'Unable to process the PDF.',
                'error'
            );
        }
    }


    // ---------------------------------------------------------
    // Download Historical Version
    // ---------------------------------------------------------

    handleHistoryDownload(event) {

        const url =
            event.currentTarget.dataset.url;


        if (url) {

            window.open(
                url,
                '_blank'
            );
        }
    }


    // ---------------------------------------------------------
    // Email Modal
    // ---------------------------------------------------------

    openEmailModal() {

        if (!this.generatedDocument) {

            this.showToast(
                'Error',
                'Generate a document before sending it.',
                'error'
            );

            return;
        }


        this.recipientEmail = '';

        this.showEmailModal = true;
    }


    closeEmailModal() {

        if (this.isSendingEmail) {

            return;
        }


        this.showEmailModal =
            false;
    }


    handleEmailChange(event) {

        this.recipientEmail =
            event.target.value;
    }


    // ---------------------------------------------------------
    // Send Email
    // ---------------------------------------------------------

    async handleSendEmail() {

        if (!this.recipientEmail) {

            this.showToast(
                'Error',
                'Please enter a recipient email address.',
                'error'
            );

            return;
        }


        if (!this.generatedDocument) {

            this.showToast(
                'Error',
                'No document is available to send.',
                'error'
            );

            return;
        }


        this.isSendingEmail = true;


        try {

            await sendDocument({

                contentVersionId:
                    this.generatedDocument
                        .contentVersionId,

                opportunityId:
                    this.recordId,

                recipientEmail:
                    this.recipientEmail

            });


            this.showToast(
                'Success',
                'Proposal sent successfully.',
                'success'
            );


            this.showEmailModal =
                false;


        } catch (error) {

            this.showError(error);

        } finally {

            this.isSendingEmail =
                false;
        }
    }


    // ---------------------------------------------------------
    // Refresh History
    // ---------------------------------------------------------

    async refreshHistory() {

        try {

            this.history =
                await getHistory({

                    opportunityId:
                        this.recordId

                });


            // Also refresh the wire so the counter stays synced
            if (this.wiredHistoryResult) {

                await refreshApex(
                    this.wiredHistoryResult
                );
            }


        } catch (error) {

            this.showError(error);
        }
    }


    // ---------------------------------------------------------
    // History Getter
    // ---------------------------------------------------------

    get hasHistory() {

        return (
            this.history &&
            this.history.length > 0
        );
    }


    // ---------------------------------------------------------
    // Delete History Document
    // ---------------------------------------------------------

    async handleDeleteHistory(event) {

        const contentDocumentId =
            event.currentTarget.dataset.documentId;


        if (!contentDocumentId) {

            return;
        }


        try {

            await deleteDocument({

                contentDocumentId:
                    contentDocumentId

            });


            // ---------------------------------------------
            // Immediately remove from UI
            // ---------------------------------------------

            this.history =
                this.history.filter(
                    document =>
                        document.contentDocumentId !==
                        contentDocumentId
                );


            // ---------------------------------------------
            // If currently displayed document was deleted
            // remove generated document workspace
            // ---------------------------------------------

            if (
                this.generatedDocument &&
                (
                    this.generatedDocument.contentDocumentId ===
                    contentDocumentId
                )
            ) {

                this.generatedDocument =
                    null;
            }


            this.showToast(
                'Success',
                'Document deleted successfully.',
                'success'
            );


        } catch (error) {

            this.showError(error);
        }
    }


    // ---------------------------------------------------------
    // Toast Helpers
    // ---------------------------------------------------------

    showToast(
        title,
        message,
        variant
    ) {

        this.dispatchEvent(
            new ShowToastEvent({

                title:
                    title,

                message:
                    message,

                variant:
                    variant

            })
        );
    }


    showError(error) {

        let message =
            'Something went wrong.';


        if (
            error &&
            error.body &&
            error.body.message
        ) {

            message =
                error.body.message;

        } else if (
            error &&
            error.message
        ) {

            message =
                error.message;
        }


        this.showToast(
            'Error',
            message,
            'error'
        );
    }
}