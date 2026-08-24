import { LightningElement } from 'lwc';
import logows from '@salesforce/resourceUrl/logows';

export default class SeFooterContact extends LightningElement {
    iconContactenosUrl = logows;

    renderedCallback() {
        const pin = document.documentElement.classList.contains('se-chrome');
        const home = document.documentElement.classList.contains('se-home');
        this.classList.toggle('se-footer-pin', pin);
        this.classList.toggle('se-footer-home', pin && home);
    }

    handleWhatsapp() {
        const phone = '5491131172022'; // Número con código de país, sin signos
        const message = 'Hola, quiero más información';
        const url = `https://wa.me/${phone}?text=${encodeURIComponent(message)}`;
        window.open(url, '_blank');
    }
}