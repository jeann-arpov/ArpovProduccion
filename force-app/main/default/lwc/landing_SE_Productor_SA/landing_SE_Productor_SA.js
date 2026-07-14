import { LightningElement, track } from 'lwc';
import getLoadData from '@salesforce/apex/HomeMulticultivo.getLoadData';
import { NavigationMixin } from 'lightning/navigation';

export default class Landing_SE_Productor_SA extends NavigationMixin(LightningElement) {
    @track tarjetasHT = [];
    currentDate;
    recordId;

    async connectedCallback() {
        const today = new Date();
        this.currentDate = `AL ${today.getDate()}/${today.getMonth() + 1}/${today.getFullYear()}`;

        try {
            let data = await getLoadData();
            data = JSON.parse(JSON.stringify(data));
            console.log(JSON.stringify(data));

            data.forEach(t => {
                t.isComprar = t.version === 'comprar';
                t.isAdherir = t.version === 'adherir';
                t.isAdherido = t.version === 'adherido';
                t.buttonLabel = t.isComprar ? 'Compra HT' : 'Adherite a PPH';
            });

            this.tarjetasHT = data;
        } catch (e) {
            console.error('Error cargando tarjetas HT', e);
        }
    }

    doAction(event) {
        const cultivoId = event.currentTarget.dataset.id;
        const cultivo = this.tarjetasHT.find(t => t.cultivo.Id === cultivoId);

        if (!cultivo) return;

        if (cultivo.isComprar) {
            // Antes: iba a /compraHT?id=<cultivoId> (no alineado con el portal).
            // this[NavigationMixin.Navigate]({
            //     type: 'standard__webPage',
            //     attributes: { url: '/compraHT?id=' + cultivoId }
            // });
            const portalBase = window.location.pathname.split('/s/')[0];
            window.location.assign(portalBase + '/s/FormularioNuevaVentaHT');
        } else if (cultivo.isAdherir) {
            // Navegación a adhesión
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/adhesion-pph?recordId=' + cultivo.paramId
                }
            });
        }
    }

    redirectToCC(event) {
        const cultivoId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/cuentaCorriente?id=' + cultivoId
            }
        });
    }
}