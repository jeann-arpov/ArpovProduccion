import { LightningElement } from 'lwc';
import logows from '@salesforce/resourceUrl/logows';

export default class FooterContact extends LightningElement {
    iconContactenosUrl = logows;

    handleWhatsapp() {
        const phone = '5491131172022'; // Número con código de país, sin signos
        const message = 'Hola, quiero más información';
        const url = `https://wa.me/${phone}?text=${encodeURIComponent(message)}`;
        window.open(url, '_blank');
    }
}