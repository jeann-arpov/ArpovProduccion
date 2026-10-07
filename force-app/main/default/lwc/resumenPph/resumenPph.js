import { LightningElement, api, track } from 'lwc';

const ESTADOS_CON_SALDO_PPH = ['En Revisión', 'Adherido', 'Vencido'];

const fmt = (n) => new Intl.NumberFormat('es-AR').format(Number(n) || 0);

const sumVariedades = (est) =>
    Object.values(est.variedades || {})
        .map((v) => Number(v.cantidad) || 0)
        .reduce((a, b) => a + b, 0);

export default class ResumenPph extends LightningElement {
    @api info;
    @track open = {};

    get cultivoName() {
        return this.info?.plan?.Parametro_PPH__r?.Cultivo__r?.Name || '';
    }

    get totalesLabel() {
        return `Hectáreas totales de ${this.cultivoName} sembradas`;
    }

    get fechaLabel() {
        const raw = this.info?.plan?.Fecha_de_Adhesion__c;
        let date = new Date();
        if (raw) {
            const [y, m, d] = String(raw).split('T')[0].split('-').map(Number);
            date = new Date(y, m - 1, d);
        }
        return `${String(date.getDate()).padStart(2, '0')}/${String(date.getMonth() + 1).padStart(2, '0')}/${date.getFullYear()}`;
    }

    get establecimientosData() {
        return this.info?.establecimientos || [];
    }

    get totalSembradoSE() {
        return this.establecimientosData.reduce((prev, e) => prev + sumVariedades(e), 0);
    }

    get totalSembrado() {
        return this.establecimientosData.reduce(
            (prev, e) => prev + sumVariedades(e) + (Number(e.cantidadNoSE) || 0),
            0
        );
    }

    get creditoDisponible() {
        const estado = this.info?.plan?.Estado__c;
        // Al enviar, lo no precertificado se reserva como HT Saldo PPH y el stock neto del cultivo queda en 0.
        if (ESTADOS_CON_SALDO_PPH.includes(estado)) {
            return Number(this.info.saldoPph) || 0;
        }
        const disponible = (Number(this.info?.total) || 0) - (estado === 'Cancelado' ? 0 : this.totalSembradoSE);
        return Math.max(0, disponible);
    }

    get totalSembradoLabel() {
        return fmt(this.totalSembrado);
    }

    get totalSembradoSELabel() {
        return fmt(this.totalSembradoSE);
    }

    get creditoDisponibleLabel() {
        return fmt(this.creditoDisponible);
    }

    get establecimientos() {
        return this.establecimientosData.map((e, idx) => {
            const key = e.pphId || e.id || `est-${idx}`;
            const isOpen = this.open[key] !== undefined ? this.open[key] : idx === 0;
            const lineas = Object.values(e.variedades || {})
                .filter((linea) => linea.cantidad > 0)
                .map((linea, i) => ({
                    key: linea.id || linea.variedad?.Id || `l-${i}`,
                    brand: linea.brand || '',
                    name: linea.variedad?.Name || '',
                    cantidadLabel: fmt(linea.cantidad)
                }));
            return {
                key,
                editId: e.id,
                index: idx + 1,
                name: e.name,
                totalSembradoLabel: fmt(sumVariedades(e) + (Number(e.cantidadNoSE) || 0)),
                georeferencia:
                    e.latitude != null && e.longitude != null
                        ? Number(e.latitude).toFixed(2) + '; ' + Number(e.longitude).toFixed(2)
                        : null,
                lineas,
                hasLineas: lineas.length > 0,
                cantidadNoSELabel: fmt(e.cantidadNoSE),
                isOpen,
                chevClass: isOpen ? 'chev open' : 'chev',
                chevPath: isOpen ? 'M18 15l-6-6-6 6' : 'M6 9l6 6 6-6',
                toggleLabel: isOpen ? 'Ocultar detalle' : 'Ver detalle'
            };
        });
    }

    get canEdit() {
        const estado = this.info?.plan?.Estado__c;
        return estado === 'En Preparación' || estado === 'Rectificado';
    }

    get canRectificar() {
        const params = this.info?.plan?.Parametro_PPH__r;
        const estado = this.info?.plan?.Estado__c;
        if (!params || (estado !== 'Adherido' && estado !== 'En Revisión')) return false;
        return this.isWithinWindow(params, 1) || this.isWithinWindow(params, 2);
    }

    isWithinWindow(params, n) {
        const start = params[`Fecha_Inicio_Rectificacion_${n}__c`];
        const end = params[`Fecha_Fin_Rectificacion_${n}__c`];
        if (!start || !end) return false;
        const now = new Date();
        return now >= new Date(start) && now <= new Date(end);
    }

    toggle(event) {
        const key = event.currentTarget.dataset.key;
        const current = this.establecimientos.find((e) => e.key === key);
        this.open = { ...this.open, [key]: !(current && current.isOpen) };
    }

    edit(event) {
        this.dispatchEvent(new CustomEvent('edit', { detail: { id: event.currentTarget.dataset.id } }));
    }

    enviar() {
        this.dispatchEvent(new CustomEvent('enviar'));
    }

    rectificar() {
        this.dispatchEvent(new CustomEvent('rectificar'));
    }

    volver() {
        this.dispatchEvent(new CustomEvent('volver'));
    }
}
