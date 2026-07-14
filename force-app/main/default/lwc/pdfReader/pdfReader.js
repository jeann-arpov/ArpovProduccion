import { LightningElement, api } from 'lwc';

export default class PdfReader extends LightningElement {
    
    showPdf = false;
    documentId; 
    title;

    handleOnLoadPDF() {
        console.log('PDF Loaded!')
    }

    @api
    show(data) {
        this.title = data.title
        this.showPdf = true;
        this.documentId = data.documentId;
    }

    @api
    hide() {
        this.showPdf = true;
        this.documentId = null;
    }

    handleOnCloseModal() {
        this.showPdf = false;
    }

    get pdfUrl(){
        return window.location.href.split('/s/')[0] + '/apex/viewPDF?documentId=' + this.documentId;
    }

}