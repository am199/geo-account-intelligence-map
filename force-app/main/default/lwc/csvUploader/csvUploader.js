import { LightningElement } from 'lwc';
import uploadCsvFile from '@salesforce/apex/CsvParserService.uploadCsvFile';

export default class CsvUploader extends LightningElement {
    fileName;
    base64Data;
    message;
    isUploading = false;

    get uploadDisabled() {
        return !this.base64Data || this.isUploading;
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) {
            return;
        }
        this.fileName = file.name;
        const reader = new FileReader();
        reader.onload = () => {
            this.base64Data = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    async upload() {
        this.isUploading = true;
        this.message = 'Uploading CSV...';
        try {
            const contentVersionId = await uploadCsvFile({
                fileName: this.fileName,
                base64Data: this.base64Data
            });
            this.message = 'CSV uploaded and stored in Salesforce Files.';
            this.dispatchEvent(new CustomEvent('fileuploaded', { detail: { contentVersionId } }));
        } catch (error) {
            this.message = error.body?.message || error.message;
        } finally {
            this.isUploading = false;
        }
    }
}