import { LightningElement, api, track } from 'lwc';
import icons from 'c/icons';
import { NavigationMixin } from 'lightning/navigation';
import { goToCommunityPage, PAGES } from 'c/seNav';

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
    @api mobileEmbedded = false;
    @track collapsed = {};

    icons = icons.pph;

    get fecha() {
        return new Date(this.info.cesion.CreatedDate);
    }

    get fechaLabel() {
        return this.fecha.toLocaleDateString('es-AR');
    }

    get toneladasTotalesCedidas() {
        return (this.info?.destinatarios || []).reduce((prev, e) => {
            return prev + Object.values(e.variedades || {}).map(v => v.cantidad).reduce((a, b) => a + b, 0);
        }, 0);
    }

    get toneladasTotalesLabel() {
        return this.formatTon(this.toneladasTotalesCedidas);
    }

    get cultivoLabel() {
        return this.info?.cesion?.Cultivo__r?.Name || '';
    }

    get tipoCesionLabel() {
        return this.info?.cesion?.Tipo_de_Cesion__c || 'Cesión';
    }

    get estadoLabel() {
        return this.info?.cesion?.Estado__c || '';
    }

    get pageTitle() {
        const estado = this.info?.cesion?.Estado__c;
        return estado === 'Pendiente de Validación'
            ? '¡Tu solicitud ya fue enviada!'
            : 'Resumen de tu solicitud';
    }

    get tnsBolsatechLabel() {
        return this.formatTon(this.info?.tnsBolsatech || 0);
    }

    formatTon(n) {
        return Number(n || 0).toLocaleString('es-AR', { maximumFractionDigits: 0 });
    }

    getlicense(linea, dest) {
        if (this.info.cesion.Estado__c != 'En Curso') return linea.license;
        return this.info.licenses.hasOwnProperty(dest) && (this.info.licenses[dest].hasOwnProperty(linea.variedad.Obtentor_Comercializa__c + mapTecnologias[linea.variedad.Biotecnologia__c]) || (linea.variedad.Obtentor_Comercializa__r.ParentId && this.info.licenses[dest].hasOwnProperty((linea.variedad.Obtentor_Comercializa__r.ParentId + mapTecnologias[linea.variedad.Biotecnologia__c]))));
    }

    get destinatarios() {
        return (this.info?.destinatarios || []).map((e) => {
            const rec = e.destinatarioRecord || {};
            const dest = {
                id: e.id,
                name: rec.Name,
                cuit: rec.N_CUIT__c,
                razonSocial: rec.ERPvs__Denominacion_Y_Razon_Social__c || rec.Name,
                address: rec.BillingAddress
            };
            dest.toneladas = Object.values(e.variedades).map(v => v.cantidad).reduce((a, b) => a + b, 0);
            dest.toneladasLabel = this.formatTon(dest.toneladas);
            dest.lineas = Object.values(e.variedades)
                .filter((linea) => linea.cantidad > 0)
                .map((l) => {
                    const license = this.getlicense(l, rec.Id);
                    return {
                        id: l.variedad?.Id || l.variedad?.Name,
                        cantidad: l.cantidad,
                        cantidadLabel: this.formatTon(l.cantidad),
                        name: l.variedad.Name,
                        icono: l.icono,
                        license,
                        licenseClass: license ? 'se-resumen-license se-resumen-license--ok' : 'se-resumen-license se-resumen-license--bad',
                        licenseLabel: license ? 'Licencia OK' : 'Sin licencia',
                        licenseTitle: license ? 'Licencia vigente' : 'Licencia pendiente'
                    };
                });
            dest.collapsed = this.collapsed[e.id] === true;
            dest.class = 'extra' + (dest.collapsed ? ' collapsed' : '');
            dest.canEdit = e.record.Estado__c == 'En Curso' || e.record.Estado__c == 'Pendiente de Validación';
            dest.enCurso = e.record.Estado__c == 'En Curso';
            return dest;
        });
    }

    get showTnsBolsatech() {
        const estado = this.info.cesion.Estado__c;
        return this.info.cesion.Cultivo__r.Name == 'SOJA' && (estado == 'En Curso' || estado == 'Pendiente de Validación');
    }

    get canSend() {
        return this.destinatarios.find(d => d.enCurso) != null;
    }

    get mobileSectionClass() {
        let cls = 'se-resumen-mob se-mob-only';
        if (this.mobileEmbedded) cls += ' se-resumen-mob--embedded';
        return cls;
    }

    get showMobileHead() {
        return !this.mobileEmbedded;
    }

    get showMobileFooter() {
        return !this.mobileEmbedded;
    }

    get canAnular() {
        return this.info.cesion.Estado__c == 'Pendiente de Validación' || this.info.cesion.Estado__c == 'En Curso';
    }

    @api
    requestEnviar() {
        this.enviar();
    }

    changeCollapsed(event) {
        const key = event.currentTarget.dataset.destinatario;
        this.collapsed = { ...this.collapsed, [key]: !this.collapsed[key] };
    }

    edit(e) {
        this.dispatchEvent(new CustomEvent('edit', { detail: { id: e.currentTarget.dataset.id } }));
    }

    enviar(e) {
        let hasLicenses = true;

        for (const dest of this.destinatarios) {
            for (const linea of dest.lineas) {
                if (linea.license == false) hasLicenses = false;
            }
        }

        this.dispatchEvent(new CustomEvent('enviar', { detail: { hasLicenses } }));
    }

    anular(e) {
        this.dispatchEvent(new CustomEvent('anular'));
    }

    redirectInicio() {
        goToCommunityPage(PAGES.cesiones);
    }
}
