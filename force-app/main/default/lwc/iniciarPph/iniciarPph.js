import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import hasHT from '@salesforce/apex/AdhesionPPH.hasHT';
import getTycDocumentos from '@salesforce/apex/AdhesionPPHHome.getTycDocumentos';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { reduceErrors } from 'c/utils';

const CULTIVO_ORDER = ['SOJA', 'TRIGO', 'CEBADA'];

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

    tycLinks = [];

    get hasTycLinks() {
        return this.tycLinks.length > 0;
    }

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
        this.loadTyc();
    }

    async loadTyc() {
        try {
            const docs = await getTycDocumentos();
            const rank = (c) => {
                const i = CULTIVO_ORDER.indexOf((c || '').toUpperCase());
                return i === -1 ? CULTIVO_ORDER.length : i;
            };
            this.tycLinks = [...(docs || [])]
                .sort((a, b) => rank(a.cultivo) - rank(b.cultivo))
                .map((d) => {
                    const nombre = (d.cultivo || '').toLowerCase();
                    const cultivo = nombre.charAt(0).toUpperCase() + nombre.slice(1);
                    return {
                        id: d.contentDocumentId,
                        label: `Ver T&C ${cultivo}`,
                        title: `Términos y Condiciones PPH · ${d.parametro}`
                    };
                });
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('[iniciarPph] getTycDocumentos', e);
            this.tycLinks = [];
        }
    }

    openTyc(event) {
        const link = this.tycLinks.find((l) => l.id === event.currentTarget.dataset.id);
        if (!link) return;
        this.template.querySelector('c-pdf-reader')?.show({
            documentId: link.id,
            title: link.title
        });
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    redirectAdhesion() {
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
