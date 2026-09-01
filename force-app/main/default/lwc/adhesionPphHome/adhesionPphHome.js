import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLoadData from '@salesforce/apex/AdhesionPPHHome.getLoadData';
import { errorEvent } from 'c/utils';

const PAGE_SIZE = 200;
const STATUS_ORDER = ['En curso', 'Sin adherir', 'Certificada', 'En rectificación', 'Rechazada', 'Vencida'];

function statusTone(estado) {
    const s = (estado || '').toLowerCase();
    if (/certific|adherid/.test(s)) return 'ok';
    if (/rechaz|vencid/.test(s)) return 'danger';
    if (/curso|rectif|prepar/.test(s)) return 'warn';
    return 'info';
}

export default class AdhesionPphHome extends NavigationMixin(LightningElement) {
    @track rowsAll = [];
    @track filtered = [];
    @track statusPills = [];
    @track cultivoOptions = [];

    loading = true;
    initialized = false;
    estadoSeleccionado = 'todas';
    cultivoSeleccionado = 'todas';
    searchKey = '';
    pageSize = PAGE_SIZE;

    rectificacionTooltip =
        'Tenés una rectificación de PPH sin finalizar. Ingresá, completá tu plan de siembra y aceptá los términos y condiciones.';

    columns = [
        { label: 'Campaña', fieldName: 'title', type: 'link' },
        { label: 'Cultivo', fieldName: 'cultivo' },
        { label: 'Período', fieldName: 'periodo' },
        { label: 'Estado', fieldName: 'statusLabel', type: 'badge', toneField: 'statusTone' },
        { label: '', fieldName: 'action', type: 'action', actionLabel: 'Abrir' }
    ];

    mobileFields = [
        { label: 'Cultivo', fieldName: 'cultivo' },
        { label: 'Período', fieldName: 'periodo' }
    ];

    connectedCallback() {
        document.documentElement.classList.add('se-inner');
        document.body.classList.add('se-inner');
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
    }

    renderedCallback() {
        if (!this.initialized) {
            this.init();
        }
    }

    async init() {
        this.initialized = true;

        try {
            const data = await getLoadData();
            this.rowsAll = this.flattenRows(data);
            this.buildFilters();
            this.applyFilters();
            this.loading = false;
        } catch (error) {
            this.loading = false;
            this.onError(error);
        }
    }

    flattenRows(data) {
        const rows = [];

        (data || []).forEach((w) => {
            (w.parametros || []).forEach((wParam) => {
                rows.push(this.decorateRow(w.cultivo, wParam));
            });
        });

        return rows;
    }

    decorateRow(cultivo, wParam) {
        const actionName = this.getActionName(wParam);
        const estadoRaw = wParam.planSiembra?.Estado__c;
        const statusLabel = this.getEstadoLabel(estadoRaw);
        const statusBucket = this.getStatusBucket(statusLabel);
        const disableAction = this.getDisableAction(wParam, actionName);
        const periodo = `Del ${this.getLocaleDateString(wParam.parametro.Fecha_Inicio_Adhesion_PPH__c)} al ${this.getLocaleDateString(wParam.parametro.Fecha_Fin_Adhesion_PPH__c)}`;

        let mobileActionLabel = 'Ver adhesión →';
        let mobileActionVariant = 'ghost';

        if (actionName === 'Adherir') {
            mobileActionLabel = 'Adherir →';
            mobileActionVariant = 'primary';
        } else if (actionName === 'Continuar') {
            mobileActionLabel = 'Continuar adhesión →';
            mobileActionVariant = 'primary';
        } else if (actionName === 'Ver' && statusLabel === 'Certificada') {
            mobileActionLabel = 'Ver certificado';
            mobileActionVariant = 'ghost';
        }

        return {
            id: wParam.parametro.Id,
            paramId: wParam.parametro.Id,
            cultivoId: cultivo.Id,
            contentDocumentId: wParam.contentDocumentId,
            title: wParam.parametro.Name,
            cultivo: cultivo.Name,
            periodo,
            statusLabel,
            statusTone: statusTone(statusLabel),
            statusBucket,
            statusNote: disableAction ? wParam.disabledCause || '' : '',
            actionName,
            actionDisabled: disableAction,
            disabledCause: wParam.disabledCause,
            mobileActionLabel,
            mobileActionVariant,
            showRectificacionInfo: estadoRaw === 'Rectificado'
        };
    }

    getStatusBucket(label) {
        if (label === 'Certificada') return 'Certificada';
        if (label === 'Sin adherir') return 'Sin adherir';
        if (label === 'En rectificación') return 'En curso';
        if (label === 'En Preparación') return 'En curso';
        if (/rechaz/i.test(label)) return 'Rechazada';
        if (/vencid/i.test(label)) return 'Vencida';
        return label;
    }

    buildFilters() {
        const cultivos = [...new Set(this.rowsAll.map((r) => r.cultivo).filter(Boolean))].sort();
        this.cultivoOptions = [
            { label: 'Todos los cultivos', value: 'todas' },
            ...cultivos.map((c) => ({ label: c, value: c }))
        ];

        const counts = {};
        this.rowsAll.forEach((r) => {
            counts[r.statusBucket] = (counts[r.statusBucket] || 0) + 1;
        });

        this.statusPills = [
            { label: 'Todas', value: 'todas', count: this.rowsAll.length, active: true },
            ...STATUS_ORDER.filter((s) => counts[s])
                .map((s) => ({
                    label: s,
                    value: s,
                    count: counts[s],
                    active: false
                }))
        ];
    }

    applyFilters() {
        let rows = [...this.rowsAll];

        if (this.estadoSeleccionado !== 'todas') {
            rows = rows.filter((r) => r.statusBucket === this.estadoSeleccionado);
        }

        if (this.cultivoSeleccionado !== 'todas') {
            rows = rows.filter((r) => r.cultivo === this.cultivoSeleccionado);
        }

        const q = (this.searchKey || '').trim().toLowerCase();
        if (q) {
            rows = rows.filter(
                (r) =>
                    (r.title || '').toLowerCase().includes(q) ||
                    (r.cultivo || '').toLowerCase().includes(q) ||
                    (r.statusLabel || '').toLowerCase().includes(q)
            );
        }

        this.filtered = rows;
    }

    handleSearchChange(event) {
        this.searchKey = event.detail?.value ?? event.detail ?? '';
        this.applyFilters();
    }

    handlePill(event) {
        const value = event.detail?.value ?? 'todas';
        this.estadoSeleccionado = value;
        this.statusPills = this.statusPills.map((p) => ({
            ...p,
            active: p.value === value
        }));
        this.applyFilters();
    }

    handleCultivo(event) {
        this.cultivoSeleccionado = event.detail?.value ?? 'todas';
        this.applyFilters();
    }

    handleRowAction(event) {
        const row = event.detail?.row;
        if (!row || row.actionDisabled) return;

        if (row.actionName === 'Adherir' || row.actionName === 'Continuar' || row.actionName === 'Ver') {
            this.redirectToParam(row.paramId);
        }
    }

    getDisableAction(wParam, actionName) {
        if (actionName !== 'Adherir' && actionName !== 'Continuar') {
            return false;
        }

        const hoy = new Date();
        wParam.disabledCause = '';

        if (
            !wParam.planSiembra ||
            wParam.planSiembra.Estado__c === 'Sin adherir' ||
            wParam.planSiembra.Estado__c === 'En Preparación'
        ) {
            if (new Date(wParam.parametro.Fecha_Inicio_Adhesion_PPH__c) > hoy) {
                wParam.disabledCause = 'El período de adhesión no ha comenzado';
                return true;
            }
            if (new Date(wParam.parametro.Fecha_Fin_Adhesion_PPH__c) < hoy) {
                wParam.disabledCause = 'El período de adhesión ya ha finalizado';
                return true;
            }
        }

        return false;
    }

    getActionName(wParam) {
        const estado = wParam.planSiembra?.Estado__c;
        if (estado == null || estado === 'Sin adherir') return 'Adherir';
        if (estado === 'Adherido' || estado === 'Rechazado' || estado === 'Vencido') return 'Ver';
        if (estado === 'En Preparación' || estado === 'Rectificado') return 'Continuar';
        return 'Ver';
    }

    getEstadoLabel(estado) {
        if (estado == null || estado === 'Sin adherir') return 'Sin adherir';
        if (estado === 'Rectificado') return 'En rectificación';
        if (estado === 'Adherido') return 'Certificada';
        if (estado === 'En Preparación') return 'En curso';
        return estado;
    }

    getLocaleDateString(date) {
        const newDate = new Date(date);
        newDate.setHours(newDate.getHours() + 3);
        return newDate.toLocaleDateString('es-AR');
    }

    redirectToParam(paramId) {
        this[NavigationMixin.GenerateUrl]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'adhesion-pph'
            }
        }).then((url) => {
            window.open(`${url}?recordId=${paramId}`, '_self');
        });
    }

    showTerminos(event) {
        const id = event.target.dataset.id;
        const row = this.rowsAll.find((r) => r.paramId === id);
        if (!row?.contentDocumentId) return;
        this.template.querySelector('c-pdf-reader').show({
            documentId: row.contentDocumentId,
            title: 'Términos y Condiciones'
        });
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }
}
