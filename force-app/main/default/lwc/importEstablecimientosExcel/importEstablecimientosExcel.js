import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import doImport from '@salesforce/apex/ImportEstablecimientosExcel.doImport';
import xlsx from '@salesforce/resourceUrl/XLSX';
import EMPTY_EXCEL from '@salesforce/resourceUrl/Establecimientos_Plantilla_Vacia';
import { loadScript } from 'lightning/platformResourceLoader';
import { reduceErrors } from 'c/utils';

const MAX_FILE_SIZE = 1500000;

export default class ImportEstablecimientosExcel extends LightningElement {

    file;
    fileName;
    fileContents;
    fileReader;
    content;
    step = "1";

    loading = false;

    connectedCallback() {
        Promise.all([loadScript(this, xlsx)]);
    }

    handleFilesChange(event) {
        if (event.target.files.length > 0) {
            this.file = event.target.files[0];
            this.fileName = this.file.name;
            this.step = 2;
        }
    }

    handleSave() {
        if(this.file) {
            this.uploadHelper();
        }else {
            this.fileName = 'Por favor suba un archivo excel para continuar';
        }
    }

    uploadHelper() {
        if (this.file.size > MAX_FILE_SIZE) {
            this.dispatchEvent(new ShowToastEvent({title: '', message: 'El tamaño del archivo es mayor al máximo permitido', variant: 'error'}));
            return;
        }

        this.loading = true;

        this.fileReader = new FileReader();
        this.fileContents = null;

        this.fileReader.onloadend = (() => {
            if(this.fileContents == null){
                this.fileContents = this.fileReader.result;
                let base64 = 'base64,';
                this.content = this.fileContents.indexOf(base64) + base64.length;
                this.fileContents = this.fileContents.substring(this.content);
                this.fileReader.readAsArrayBuffer(this.file);
                
            }else {
                let workbook = XLSX.read(new Uint8Array(this.fileReader.result), { type: 'array' });
                let sheetNameList = workbook.SheetNames;
                this.uploadFile(XLSX.utils.sheet_to_json(workbook.Sheets[sheetNameList[0]], {raw:false}));
            }
        });

        this.fileReader.readAsDataURL(this.file);
    }

    uploadFile(rows) {
        console.log(rows);
        doImport({fileRows: rows}).then(result => {
            this.generateFileResults(result);
            this.loading = false;
        }).catch(error => {
            this.loading = false;
            this.showMessage('Error de Importacion', reduceErrors(error).join('\n'), 'error');
        });
    }

    generateFileResults(data){
        if(!data[0].isSuccess){
            this.showMessage('Error de Importacion', 'Revisar errores en Excel de resultados', 'error');
            this.backStep();
            delete data[0].isSuccess; 
            let ws = XLSX.utils.json_to_sheet(data);
            let wb = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(wb, ws, "resultados");
            let n = XLSX.writeFile(wb, 'resultados.xlsx');
        }else {
            this.showMessage('', 'Los Establecimientos fueron importados con éxito', 'success');
            this.step = "3";
            window.location.reload();
        }
    }

    showMessage(title, message, variant){
        this.dispatchEvent(new ShowToastEvent({title, message, variant}));
    }
    
    downloadClick(){
        let downloadElement = document.createElement('a');
        downloadElement.href = EMPTY_EXCEL;
        downloadElement.target = '_self';
        downloadElement.download = 'Establecimientos Plantilla.xlsx';
        document.body.appendChild(downloadElement);
        downloadElement.click(); 
    }

    backStep(){
        this.step = "1";
    }

    closeModal() {
        this.template.querySelector('c-modal').hide();
        this.backStep();
    }

    openModal() {
        this.template.querySelector('c-modal').show();
    }

    get header(){
        if(this.step == "1") return "Adjuntar el archivo Excel a importar";
        if(this.step == "2") return "Confirmar la importación del archivo";
        if(this.step == "3") return "Finalizado";
    }

    get comenzado(){
        return this.step == "1";
    }

    get confirmado(){
        return this.step == "2";
    }

    get finalizado(){
        return this.step == "3";
    }

    get fileSize(){
        let i = Math.floor(Math.log(this.file.size) / Math.log(1024));
        return " (" + ((this.file.size / Math.pow(1024, i)).toFixed(2) * 1 + ' ' + ['B', 'kB', 'MB', 'GB', 'TB'][i] + ")");
    }

    get acceptedFormats() {
        return ['.xlsx', '.csv'];
    }
}