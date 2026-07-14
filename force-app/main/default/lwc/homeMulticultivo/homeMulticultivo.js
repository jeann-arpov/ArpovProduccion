import { LightningElement, wire } from 'lwc';
import getLoadData from '@salesforce/apex/HomeMulticultivo.getLoadData';
import { errorEvent } from 'c/utils';

/*
    navigation mixin da error: SecureWindow.open supports http:, https:, mailto: schemes and relative urls.
    window.parent.location.href no es accesible desde lwc entonces uso window.location.href
*/
const SITE_URL = window.location.href.split('apex/')[0];

export default class HomeMulticultivo extends LightningElement {

    tarjetas;

    currentPage = 1;
    cardsPerPage = 3;

    initialized = false;

    async init(){
        this.initialized = true;

        try {
            let data = await getLoadData();
            console.log(data);
            data = JSON.parse(JSON.stringify(data));
            data.forEach((t, i) => {
                t.isComprar = t.version == 'comprar';
                t.isAdherir = t.version == 'adherir';
                t.isAdherido = t.version == 'adherido';
                t.buttonLabel = t.isComprar ? 'Compra HT' : 'Adherite a PPH';
                t.saldoClass = t.isAdherido ? 'saldo-adherido' : 'saldo-no-adherido';
                t.buttonClass = `action-button${t.isComprar ? ' button-comprar' : ''}`;
            });
            this.tarjetas = data;
        } catch (error) {
            this.onError(error);
        }
    }

    renderedCallback(){
        if(!this.initialized) this.init();
    }

    doAction(event){
        const tarjeta = this.tarjetas.find(t => t.cultivo.Id == event.target.dataset.id);

        if(tarjeta.isComprar){
            window.open(`${SITE_URL}s/editar-compra?cultivoId=${tarjeta.cultivo.Id}`, '_parent');
        }

        if(tarjeta.isAdherir){
            window.open(`${SITE_URL}s/adhesion-pph?recordId=${tarjeta.paramId}`, '_parent');
        }
    }

    redirectToCC(event){
        const cultivo = this.tarjetas.find(t => t.cultivo.Id == event.target.dataset.id).cultivo;
        window.open(`${SITE_URL}s/cuenta-granaria?cultivoId=${cultivo.Id}`, '_parent');
    }

    onError(e){
        this.dispatchEvent(errorEvent(e));
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage += 1;
        }
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleDotClick(event) {
        this.currentPage = parseInt(event.target.dataset.page);
    }

    get currentCards() {
        const startIndex = (this.currentPage - 1) * this.cardsPerPage;
        const endIndex = startIndex + this.cardsPerPage;
        return this.tarjetas.slice(startIndex, endIndex);
    }

    get pagesArray() {
        const pages = [];
        for (let i = 1; i <= this.totalPages; i++) {
            const isActive = i === this.currentPage;
            pages.push({pageNumber: i, class: `dot ${isActive ? 'active' : ''}`});
        }
        return pages;
    }

    get totalPages() {
        return Math.ceil(this.tarjetas.length / this.cardsPerPage);
    }

    get isFirstPage(){
        return this.currentPage == 1;
    }

    get isLastPage(){
        return this.currentPage == this.totalPages;
    }
}