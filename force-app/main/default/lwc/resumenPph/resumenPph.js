import { LightningElement, api, track } from 'lwc';

export default class ResumenPph extends LightningElement {
    @api info;
    @track collapsed = {};

    get fecha() {
        return this.info.plan.Fecha_de_Adhesion__c ? this.info.plan.Fecha_de_Adhesion__c : new Date();
    }

    renderedCallback() {
        console.log(JSON.parse(JSON.stringify(this.info)))
    }

    get totalSembrado() {
        return this.info.establecimientos.reduce((prev, e) => {
            return prev + Object.values(e.variedades).map(v => v.cantidad).reduce((a, b) => a + b, 0) + e.cantidadNoSE;
        }, 0);
    }

    get totalSembradoSE() {
        return this.info.establecimientos.reduce((prev, e) => {
            return prev + Object.values(e.variedades).map(v => v.cantidad).reduce((a, b) => a + b, 0);
        }, 0);
    }

    get creditoDisponible() {
        if(this.info.plan.Estado__c == 'Adherido'){
            return this.info.saldoPph;
        }
        return this.info.total - (this.info.plan.Estado__c == 'Cancelado' ? 0 : this.totalSembradoSE);
    }

    get establecimientos() {
        return this.info.establecimientos.map((e, idx) => {
            const est = {id: e.id, name: e.name};
            est.totalSembrado = Object.values(e.variedades).map(v => v.cantidad).reduce((a, b) => a + b, 0) + e.cantidadNoSE;
            est.georeferencia = this.info.grandesCuentas == false ? Number(e.latitude).toFixed(2) + '; ' + Number(e.longitude).toFixed(2) : null;
            est.index = idx + 1;
            est.lineas = Object.values(e.variedades).filter(e => e.cantidad > 0);
            est.cantidadNoSE = e.cantidadNoSE;
            est.class = 'extra' + (this.collapsed[e.id] != false ? ' collapsed' : '');
            est.collapsed = this.collapsed[e.id] != false;
            return est;
        });
    }

    get canEdit() {
        return this.info.plan.Estado__c == 'En Preparación' || this.info.plan.Estado__c == 'Rectificado';
    }

    get title() {
        return this.canEdit ? 'Tu solicitud de Adhesión esta lista para ser enviada' : 'Tu solicitud de Adhesión ya fue enviada';
    }

    get canRectificar() {
        const params = this.info.plan.Parametro_PPH__r;
        return this.info.plan.Estado__c == 'Adherido' && params.Fecha_Inicio_Rectificacion_1__c != null && params.Fecha_Fin_Rectificacion_1__c != null && new Date() >= new Date(params.Fecha_Inicio_Rectificacion_1__c) && new Date() <= new Date(params.Fecha_Fin_Rectificacion_1__c);
    }

    changeCollapsed(event) {
        const key = event.target.dataset.establecimiento;
        this.collapsed[key] = this.collapsed[key] == false;
    }

    edit(e) {
        this.dispatchEvent(new CustomEvent('edit', {detail: {id: e.target.dataset.id}}));
    }

    enviar(e) {
        this.dispatchEvent(new CustomEvent('enviar'));
    }

    rectificar(e) {
        this.dispatchEvent(new CustomEvent('rectificar'));
    }

    get totalesSembradasLabel() {
        return `Hectáreas TOTALES de ${this.info.plan.Parametro_PPH__r.Cultivo__r.Name} Sembradas`;
    }
}