import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLoadData from '@salesforce/apex/AdhesionPPHHome.getLoadData';
import getContext from '@salesforce/apex/AdhesionPPHHome.getContext';
import { errorEvent } from 'c/utils';
import { trackGa4Event } from 'c/portalGa4Events';

const PAGE_SIZE = 200;

const ESTADO_TONE = {
    Adherido: 'pph-adherido',
    Rectificado: 'pph-rectificado',
    Rechazado: 'pph-rechazado',
    'En Preparación': 'pph-preparacion',
    'En Revisión': 'pph-revision',
    Vencido: 'pph-vencido'
};

function statusTone(estado) {
    return ESTADO_TONE[estado] || 'pph-no-adherido';
}

function campaignTitle(paramName) {
    const raw = (paramName || '').trim();
    if (!raw) return 'Campaña';
    if (/^campa[nñ]a\b/i.test(raw)) return raw;
    const yearMatch = raw.match(/(\d{2}\s*\/\s*\d{2}|\d{4})/);
    if (yearMatch) return `Campaña ${yearMatch[1].replace(/\s+/g, '')}`;
    return raw;
}

export default class AdhesionPphHome extends NavigationMixin(LightningElement) {
    @track rowsAll = [];

    loading = true;
    initialized = false;
    pageSize = PAGE_SIZE;
    accountContext = null;

    columns = [
        { label: 'Campaña', fieldName: 'title', type: 'link' },
        { label: 'Cultivo', fieldName: 'cultivo' },
        { label: 'Establecimiento', fieldName: 'establecimientoLabel' },
        { label: 'Período', fieldName: 'periodo' },
        { label: 'Estado', fieldName: 'statusLabel', type: 'badge', toneField: 'statusTone' },
        { label: '', fieldName: 'action', type: 'action', actionLabel: 'Abrir' }
    ];

    mobileFields = [
        { label: 'Cultivo', fieldName: 'cultivo' },
        { label: 'Establecimiento', fieldName: 'establecimientoLabel' },
        { labelFieldName: 'mobileExtraLabel', fieldName: 'mobileExtraValue' }
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
            const [data, context] = await Promise.all([getLoadData(), getContext()]);
            this.accountContext = context;
            this.rowsAll = this.flattenRows(data);
            this.loading = false;
            trackGa4Event('pph_vista');
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

        let mobileActionLabel = 'Ver historial';
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
            title: campaignTitle(wParam.parametro.Name),
            cultivo: cultivo.Name,
            establecimientoLabel: wParam.establecimientoLabel || '—',
            mobileExtraLabel: wParam.mobileExtraLabel || '',
            mobileExtraValue: wParam.mobileExtraValue || '',
            periodo,
            statusLabel,
            statusTone: statusTone(estadoRaw),
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
        if (label === 'Sin Adherir' || label === 'Sin adherir') return 'Sin adherir';
        if (label === 'En rectificación') return 'En curso';
        if (label === 'En curso') return 'En curso';
        if (label === 'En Preparación') return 'En curso';
        if (label === 'Cerrada') return 'Vencida';
        if (/rechaz/i.test(label)) return 'Rechazada';
        if (/vencid/i.test(label)) return 'Vencida';
        return label;
    }

    getActionName(wParam) {
        const estado = wParam.planSiembra?.Estado__c;
        if (estado == null || estado === 'Sin adherir') return 'Adherir';
        if (estado === 'Adherido' || estado === 'Rechazado' || estado === 'Vencido') return 'Ver';
        if (estado === 'En Preparación' || estado === 'Rectificado') return 'Continuar';
        return 'Ver';
    }

    handleRowAction(event) {
        const row = event.detail?.row;
        if (!row || row.actionDisabled) return;

        if (row.actionName === 'Adherir' || row.actionName === 'Continuar') {
            trackGa4Event('pph_declaracion_iniciada');
        }

        if (row.actionName === 'Adherir' || row.actionName === 'Continuar' || row.actionName === 'Ver') {
            this.redirectToParam(row.paramId);
        }
    }

    handleAddEstablecimiento() {
        this.template.querySelector('c-establecimientos-map')?.openNew?.();
    }

    handleNoVeoHts() {
        const cuit = this.accountContext?.cuit || '';
        this.template.querySelector('c-informar-pago')?.show({
            title: 'No veo mis HTs',
            subject: `CUIT: ${cuit} · PPH`,
            accountId: this.accountContext?.accountId,
            variant: 'sg'
        });
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
            const inicio = this.parseLocalDate(wParam.parametro.Fecha_Inicio_Adhesion_PPH__c);
            const fin = this.parseLocalDate(wParam.parametro.Fecha_Fin_Adhesion_PPH__c);
            if (fin) fin.setHours(23, 59, 59, 999);
            if (inicio && inicio > hoy) {
                wParam.disabledCause = 'El período de adhesión no ha comenzado';
                return true;
            }
            if (fin && fin < hoy) {
                wParam.disabledCause = 'El período de adhesión ya ha finalizado';
                return true;
            }
        }

        return false;
    }

    parseLocalDate(value) {
        if (!value) return null;
        const [y, m, d] = String(value).substring(0, 10).split('-').map(Number);
        if (!y || !m || !d) return null;
        return new Date(y, m - 1, d);
    }

    getEstadoLabel(estado) {
        if (estado == null || estado === 'Sin adherir') return 'Sin Adherir';
        if (estado === 'Rectificado') return 'En rectificación';
        if (estado === 'Adherido') return 'Certificada';
        if (estado === 'En Preparación') return 'En curso';
        if (estado === 'Vencido') return 'Cerrada';
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
