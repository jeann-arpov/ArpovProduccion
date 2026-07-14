import { LightningElement, api, track } from 'lwc';
import icons from 'c/icons';
import { NavigationMixin } from 'lightning/navigation';

const mapTecnologias = {
    'RR1': 'RR',
    'RR2 - BT': 'RR',
    'BGRR': 'RR',
    'Convencional': 'RR',
    'Enlist E3': 'Enlist',
    'Conkesta E3': 'Enlist'
};

export default class ResumenCesionPph extends NavigationMixin(LightningElement) {
    @api info;
    @track collapsed = {};

    icons = icons.pph;

    get fecha() {
        return new Date(this.info.cesion.CreatedDate);
    }

    get toneladasTotalesCedidas() {
        return this.info.destinatarios.reduce((prev, e) => {
            return prev + Object.values(e.variedades).map(v => v.cantidad).reduce((a, b) => a + b, 0);
        }, 0);
    }

    getlicense(linea, dest) {
        if (this.info.cesion.Estado__c != 'En Curso') return linea.license;
        return this.info.licenses.hasOwnProperty(dest) && (this.info.licenses[dest].hasOwnProperty(linea.variedad.Obtentor_Comercializa__c + mapTecnologias[linea.variedad.Biotecnologia__c]) || (linea.variedad.Obtentor_Comercializa__r.ParentId && this.info.licenses[dest].hasOwnProperty((linea.variedad.Obtentor_Comercializa__r.ParentId + mapTecnologias[linea.variedad.Biotecnologia__c]))));
    }

    get destinatarios() {
        return this.info.destinatarios.map(e => {
            const dest = {id: e.id, name: e.destinatarioRecord.Name, cuit: e.destinatarioRecord.N_CUIT__c, razonSocial: e.destinatarioRecord.ERPvs__Denominacion_Y_Razon_Social__c, address: e.destinatarioRecord.BillingAddress};
            dest.toneladas = Object.values(e.variedades).map(v => v.cantidad).reduce((a, b) => a + b, 0);
            dest.lineas = Object.values(e.variedades).filter(e => e.cantidad > 0).map(l => ({cantidad: l.cantidad, name: l.variedad.Name, icono: l.icono, license: this.getlicense(l, e.destinatarioRecord.Id)}));
            dest.class = 'extra' + (this.collapsed[e.id] != false ? ' collapsed' : '');
            dest.collapsed = this.collapsed[e.id] != false;
            dest.canEdit = e.record.Estado__c == 'En Curso' || e.record.Estado__c == 'Pendiente de Validación';
            dest.enCurso = e.record.Estado__c == 'En Curso';
            return dest;
        });
    }

    get showTnsBolsatech(){
        return this.info.cesion.Cultivo__r.Name == 'SOJA' && this.info.cesion.Estado__c == 'En Curso' || this.info.cesion.Estado__c == 'Pendiente de Validación';
    }

    get canSend() {
        return this.destinatarios.find(d => d.enCurso) != null;
    }

    get canAnular() {
        return this.info.cesion.Estado__c == 'Pendiente de Validación' || this.info.cesion.Estado__c == 'En Curso';
    }

    changeCollapsed(event) {
        const key = event.target.dataset.destinatario;
        this.collapsed[key] = this.collapsed[key] == false;
    }

    edit(e) {
        this.dispatchEvent(new CustomEvent('edit', {detail: {id: e.target.dataset.id}}));
    }

    enviar(e) {
        let hasLicenses = true;

        for (const dest of this.destinatarios) {
            for (const linea of dest.lineas) {
                if (linea.license == false) hasLicenses = false;
                console.log(linea)
            }
        }

        this.dispatchEvent(new CustomEvent('enviar', {detail: {hasLicenses}}));
    }

    anular(e) {
        this.dispatchEvent(new CustomEvent('anular'));
    }

    redirectInicio() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'home'
            },
        });
    }
}