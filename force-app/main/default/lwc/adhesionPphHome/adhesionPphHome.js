import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLoadData from '@salesforce/apex/AdhesionPPHHome.getLoadData';
import { errorEvent } from 'c/utils';
import { trackGa4Event } from 'c/portalGa4Events';

const ESTADO_LABEL = {
    'Sin adherir': 'Sin adherir',
    'En Preparación': 'En preparación',
    'En Revisión': 'En revisión',
    Rectificado: 'En rectificación',
    Adherido: 'Adherido',
    Rechazado: 'Rechazado',
    Vencido: 'Vencido'
};

const ESTADO_TONE = {
    'En Revisión': 'warn',
    Rectificado: 'warn',
    Adherido: 'ok',
    Rechazado: 'danger'
};

export default class AdhesionPphHome extends NavigationMixin(LightningElement) {
    @track groups = [];

    loading = true;
    initialized = false;

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

    get isEmpty() {
        return !this.loading && this.groups.length === 0;
    }

    async init() {
        this.initialized = true;

        try {
            const data = await getLoadData();
            this.groups = (data || [])
                .filter((w) => (w.parametros || []).length)
                .map((w) => ({
                    id: w.cultivo.Id,
                    name: w.cultivo.Name,
                    plans: w.parametros.map((wParam) => this.decoratePlan(wParam))
                }));
            this.loading = false;
            trackGa4Event('pph_vista');
        } catch (error) {
            this.loading = false;
            this.onError(error);
        }
    }

    decoratePlan(wParam) {
        const estado = wParam.planSiembra?.Estado__c || 'Sin adherir';
        const actionName = this.getActionName(estado);
        const actionDisabled = this.getDisableAction(wParam, estado, actionName);

        return {
            id: wParam.parametro.Id,
            title: wParam.parametro.Name,
            periodo: `Adhesión de ${this.formatDate(wParam.parametro.Fecha_Inicio_Adhesion_PPH__c)} a ${this.formatDate(wParam.parametro.Fecha_Fin_Adhesion_PPH__c)}`,
            statusLabel: ESTADO_LABEL[estado] || estado,
            badgeClass: `pph-badge pph-badge-${ESTADO_TONE[estado] || 'info'}`,
            actionName,
            actionLabel: actionName,
            btnClass: actionName === 'Ver' ? 'pph-btn pph-btn-ghost' : 'pph-btn pph-btn-primary',
            actionDisabled,
            disabledCause: wParam.disabledCause,
            contentDocumentId: wParam.contentDocumentId,
            hasTerminos: !!wParam.contentDocumentId
        };
    }

    getActionName(estado) {
        if (estado === 'Sin adherir') return 'Adherir';
        if (estado === 'En Preparación' || estado === 'Rectificado') return 'Continuar';
        return 'Ver';
    }

    getDisableAction(wParam, estado, actionName) {
        if (actionName !== 'Adherir' && actionName !== 'Continuar') return false;
        if (estado !== 'Sin adherir' && estado !== 'En Preparación') return false;

        const hoy = new Date();
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
        return false;
    }

    parseLocalDate(value) {
        if (!value) return null;
        const [y, m, d] = String(value).substring(0, 10).split('-').map(Number);
        if (!y || !m || !d) return null;
        return new Date(y, m - 1, d);
    }

    formatDate(value) {
        const date = this.parseLocalDate(value);
        return date ? date.toLocaleDateString('es-AR') : '—';
    }

    findPlan(id) {
        for (const group of this.groups) {
            const plan = group.plans.find((p) => p.id === id);
            if (plan) return plan;
        }
        return null;
    }

    handleAction(event) {
        const plan = this.findPlan(event.currentTarget.dataset.id);
        if (!plan || plan.actionDisabled) return;

        if (plan.actionName === 'Adherir' || plan.actionName === 'Continuar') {
            trackGa4Event('pph_declaracion_iniciada');
        }
        this.redirectToParam(plan.id);
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
        const plan = this.findPlan(event.currentTarget.dataset.id);
        if (!plan?.contentDocumentId) return;
        this.template.querySelector('c-pdf-reader').show({
            documentId: plan.contentDocumentId,
            title: 'Términos y Condiciones',
            barLabel: 'T&C PPH',
            variant: 'sg'
        });
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }
}
