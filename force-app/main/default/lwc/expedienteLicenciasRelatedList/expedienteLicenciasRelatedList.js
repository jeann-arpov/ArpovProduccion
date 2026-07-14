import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import getLicenciasForExpediente from '@salesforce/apex/ExpedienteLicenciasRelatedListController.getLicenciasForExpediente';
import getUrl from '@salesforce/apex/SolicitarLicencia.getUrl';
import singleLicenseJWTSigner from '@salesforce/apex/CustomJWTSigner.singleLicenseJWTSigner';
import uId from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import CONTACT_ID from '@salesforce/schema/User.ContactId';

export default class ExpedienteLicenciasRelatedList extends NavigationMixin(LightningElement) {
    @api recordId;

    /** Referencia de página (Experience Cloud / portal); complementa recordId cuando el host no lo pasa. */
    currentPageReference;

    pageNumber = 1;
    pageSize = 10;

    licencias = [];
    errorMessage;
    loading = true;
    loadError;
    totalRecords = 0;
    totalPages = 0;

    /** Base URL del portal (misma fuente que licenciasList). */
    url;
    currentUserId = uId;
    currentContactId;
    isOpeningPortal = false;

    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        this.currentPageReference = pageRef;
    }

    @wire(getUrl, {})
    wiredGetUrl({ error, data }) {
        if (data) {
            this.url = data;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('[expedienteLicenciasRL] Error getting portal URL:', error);
        }
    }

    @wire(getRecord, { recordId: '$currentUserId', fields: [CONTACT_ID] })
    wiredContactId({ error, data }) {
        if (data) {
            this.currentContactId = data.fields.ContactId.value;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('[expedienteLicenciasRL] Error loading user ContactId:', error);
        }
    }

    /**
     * Id del expediente: primero @api recordId (record page estándar), luego state de la ruta en comunidad,
     * luego un segmento del path tipo .../expediente-de-negativos/a7O.../exp2014... (portal Sembra).
     */
    get effectiveExpedienteId() {
        if (this.recordId) {
            return this.recordId;
        }
        const ref = this.currentPageReference;
        if (ref) {
            const state = ref.state || {};
            const fromState = [state.recordId, state.c__recordId, state.id].find((v) => this.isSalesforceId(v));
            if (fromState) {
                return fromState;
            }
            const attrs = ref.attributes || {};
            if (this.isSalesforceId(attrs.recordId)) {
                return attrs.recordId;
            }
        }
        if (typeof window !== 'undefined') {
            const segments = (window.location.pathname || '').split('/').filter(Boolean);
            const fromPath = segments.find((segment) => this.isSalesforceId(segment));
            if (fromPath) {
                return fromPath;
            }
        }
        return undefined;
    }

    isSalesforceId(value) {
        return typeof value === 'string' && /^[a-zA-Z0-9]{15,18}$/.test(value);
    }

    @wire(getLicenciasForExpediente, {
        expedienteId: '$effectiveExpedienteId',
        pageNumber: '$pageNumber',
        pageSize: '$pageSize'
    })
    wiredLicencias(result) {
        this.loading = result.loading;
        // Depuración: DevTools del navegador (F12) → pestaña Console; filtrar por [expedienteLicenciasRL]
        // eslint-disable-next-line no-console
        console.log('[expedienteLicenciasRL] wire', {
            loading: result.loading,
            recordId: this.recordId,
            effectiveExpedienteId: this.effectiveExpedienteId,
            pageNumber: this.pageNumber,
            pageSize: this.pageSize,
            hasData: !!result.data,
            hasError: !!result.error,
            diagnostico: result.data?.diagnostico,
            totalRecords: result.data?.totalRecords,
            error: result.error
        });
        if (result.data) {
            this.errorMessage = result.data.errorMessage;
            this.totalRecords = result.data.totalRecords != null ? result.data.totalRecords : 0;
            this.totalPages = result.data.totalPages != null ? result.data.totalPages : 0;
            if (result.data.pageNumber != null) {
                this.pageNumber = result.data.pageNumber;
            }
            this.loadError = undefined;

            const rows = result.data.licencias || [];
            this.licencias = rows.map((row) => ({
                id: row.id,
                name: row.name
            }));
        } else if (result.error) {
            this.licencias = [];
            this.totalRecords = 0;
            this.totalPages = 0;
            this.loadError = this.reduceError(result.error);
            this.errorMessage = undefined;
        }
    }

    handleOpenLicencia(event) {
        event.preventDefault();
        const licenseId = event.currentTarget.dataset.id;
        if (!licenseId) {
            return;
        }
        if (!this.url) {
            // eslint-disable-next-line no-console
            console.error('[expedienteLicenciasRL] Portal URL not ready yet');
            return;
        }
        if (!this.currentContactId) {
            // eslint-disable-next-line no-console
            console.error('[expedienteLicenciasRL] ContactId not available for JWT');
            return;
        }
        this.isOpeningPortal = true;
        console.log('[expedienteLicenciasRL] Opening portal for license:', licenseId);
        console.log('[expedienteLicenciasRL] Current User ID:', this.currentUserId);
        console.log('[expedienteLicenciasRL] Current Contact ID:', this.currentContactId);
        console.log('[expedienteLicenciasRL] Portal URL:', this.url);
        singleLicenseJWTSigner({
            userId: this.currentUserId,
            contactId: this.currentContactId,
            licenseId
        })
            .then((token) => {
                this[NavigationMixin.Navigate](
                    {
                        type: 'standard__webPage',
                        attributes: {
                            url: this.url + '?token=' + token + '&url=' + window.location.href
                        }
                    },
                    true
                );
            })
            .catch((err) => {
                // eslint-disable-next-line no-console
                console.error('[expedienteLicenciasRL] JWT / navigate error:', err);
            })
            .finally(() => {
                this.isOpeningPortal = false;
            });
    }

    get titulo() {
        const n = this.totalRecords != null ? this.totalRecords : 0;
        return n === 1 ? 'Licencias (1)' : 'Licencias (' + n + ')';
    }

    get hayFilas() {
        return this.licencias && this.licencias.length > 0;
    }

    get mostrarVacío() {
        return !this.loading && !this.hayFilas && !this.loadError && !this.errorMessage;
    }

    get mostrarPaginacion() {
        return this.totalRecords > this.pageSize;
    }

    get textoPagina() {
        if (!this.totalRecords) {
            return '';
        }
        return 'Página ' + this.pageNumber + ' de ' + (this.totalPages || 1);
    }

    get disablePrev() {
        return this.pageNumber <= 1 || this.loading;
    }

    get disableNext() {
        return this.pageNumber >= this.totalPages || this.loading || this.totalPages < 1;
    }

    handlePrev() {
        if (this.pageNumber > 1) {
            this.pageNumber -= 1;
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber += 1;
        }
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (typeof error.body?.message === 'string') {
            return error.body.message;
        }
        if (typeof error.message === 'string') {
            return error.message;
        }
        return 'Error al cargar las licencias.';
    }
}