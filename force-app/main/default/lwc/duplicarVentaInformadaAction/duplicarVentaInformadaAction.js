import { api, LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import getVentaInformadaById from '@salesforce/apex/VentasInformadasController.getVentaInformadaById';
import VentaInformadaModal from 'c/ventaInformadaModal';

export default class DuplicarVentaInformadaAction extends LightningElement {
    @api recordId;
    @api pageRef;

    initialized = false;
    isLoading = true;

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        this.pageRef = pageRef;
    }

    renderedCallback() {
        const effectiveRecordId = this.getEffectiveRecordId();
        if (!this.initialized && effectiveRecordId) {
            this.init(effectiveRecordId);
        }
    }

    getEffectiveRecordId() {
        if (this.recordId) {
            return this.recordId;
        }

        const state = this.pageRef?.state || {};
        const stateCandidates = [state.recordId, state.c__recordId, state.id];
        const stateRecordId = stateCandidates.find((value) => this.isSalesforceId(value));
        if (stateRecordId) {
            return stateRecordId;
        }

        const pathSegments = (window?.location?.pathname || '')
            .split('/')
            .filter(Boolean);
        const pathRecordId = pathSegments.find((segment) => this.isSalesforceId(segment));
        if (pathRecordId) {
            return pathRecordId;
        }

        return null;
    }

    isSalesforceId(value) {
        return typeof value === 'string' && /^[a-zA-Z0-9]{15,18}$/.test(value);
    }

    async init(effectiveRecordId) {
        this.initialized = true;
        console.log('[DuplicarVentaInformadaAction] init -> effectiveRecordId', effectiveRecordId);
        try {
            const data = await getVentaInformadaById({ ventaId: effectiveRecordId });
            await VentaInformadaModal.open({
                size: 'large',
                modalTitle: 'Duplicar Venta Informada',
                prefillData: data
            });
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'Error al abrir duplicado',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
}