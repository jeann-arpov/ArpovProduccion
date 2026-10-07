import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import hasHT from '@salesforce/apex/AdhesionPPH.hasHT';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { reduceErrors } from 'c/utils';

const TYC_PPH_LINKS = [
    {
        id: 'soja',
        label: 'Ver T&C Soja',
        url: 'https://sembraevolucion.com.ar/wp-content/uploads/2026/10/Terminos-y-Condiciones_Soja_PPH_Campana_26_27.pdf'
    },
    {
        id: 'trigo',
        label: 'Ver T&C Trigo',
        url: 'https://sembraevolucion.com.ar/wp-content/uploads/2026/10/Terminos-y-Condiciones_Trigo_PPH_Campana_26_27.pdf'
    },
    {
        id: 'cebada',
        label: 'Ver T&C Cebada',
        url: 'https://sembraevolucion.com.ar/wp-content/uploads/2026/09/Terminos-y-Condiciones_Cebada_PPH_Campana_26_27.pdf'
    }
];

export default class IniciarPph extends NavigationMixin(LightningElement) {
    initialized = false;
    loaded = false;
    hasHTs;

    requisitos = [
        { id: 'lic', label: 'Contar con licencia de uso vigente.' },
        { id: 'ht', label: 'Tener HT acreditadas.' },
        { id: 'cap', label: 'Indicar la capacidad productiva TOTAL por CUIT.' },
        {
            id: 'geo',
            label:
                'Georreferenciar todos los establecimientos donde sembrás (tanto variedades bajo Sembrá Evolución como las que no lo son).'
        },
        {
            id: 'tyc',
            label:
                'Aceptar los términos y condiciones del Programa Precertificación de Hectáreas (PPH)'
        }
    ];

    tycLinks = TYC_PPH_LINKS;

    connectedCallback() {
        document.documentElement.classList.add('se-inner');
        document.body.classList.add('se-inner');
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
    }

    async init() {
        this.initialized = true;

        try {
            this.hasHTs = await hasHT();
            this.loaded = true;
        } catch (e) {
            this.onError(e);
        }
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    redirectAdhesion() {
        // Desde "Adherí a PPH" del Home llega el parámetro del cultivo: sigue al paso a paso.
        const recordId = new URL(window.location.href).searchParams.get('recordId');
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: '/adhesion-pph?recordId=' + encodeURIComponent(recordId) }
            });
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'pre-certificacion'
            }
        });
    }

    redirectComprar() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'FormularioNuevaVentaHT'
            }
        });
    }

    onError(e) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: reduceErrors(e).join('\n'),
                variant: 'error',
                mode: 'sticky'
            })
        );
    }
}
