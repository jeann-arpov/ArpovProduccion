import { LightningElement, api } from 'lwc';

export default class PdfReader extends LightningElement {
    
    showPdf = false;
    documentId; 
    title;
    variant;
    barLabel;

    get showSgModal() {
        return this.showPdf && this.variant === 'sg';
    }

    get showLegacyModal() {
        return this.showPdf && this.variant !== 'sg';
    }

    handleOnLoadPDF() {
        console.log('PDF Loaded!')
    }

    @api
    show(data) {
        this.title = data.title
        this.variant = data.variant;
        this.barLabel = data.barLabel || data.title;
        this.showPdf = true;
        this.documentId = data.documentId;
    }

    @api
    hide() {
        this.showPdf = false;
        this.documentId = null;
    }

    handleOnCloseModal() {
        this.showPdf = false;
    }

    get pdfUrl(){
        return window.location.href.split('/s/')[0] + '/apex/viewPDF?documentId=' + this.documentId;
    }

}