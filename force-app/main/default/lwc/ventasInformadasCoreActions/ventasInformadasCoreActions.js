import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ACCOUNT_NAME from '@salesforce/schema/Account.Name';
import ACCOUNT_CUIT from '@salesforce/schema/Account.N_CUIT__c';
import ACCOUNT_TYPE from '@salesforce/schema/Account.Type';
import buscarCuentaOriginantePorCuit from '@salesforce/apex/CrearVentaInformadaLWCController.buscarCuentaOriginantePorCuit';
import getCuenta from '@salesforce/apex/CrearVentaInformadaLWCController.getCuenta';

const ACCOUNT_FIELDS = [ACCOUNT_NAME, ACCOUNT_CUIT, ACCOUNT_TYPE];
const ACCOUNT_KEY_PREFIX = '001';

export default class VentasInformadasCoreActions extends LightningElement {
    @api recordId;

    selectedAccountId;
    selectedAccountName;
    selectedAccountCuit;
    cuitBusqueda = '';
    isSearchingCuit = false;

    @wire(getRecord, { recordId: '$accountRecordId', fields: ACCOUNT_FIELDS })
    wiredAccount({ data, error }) {
        if (data) {
            this.selectedAccountId = data.id;
            this.selectedAccountName = getFieldValue(data, ACCOUNT_NAME);
            this.selectedAccountCuit = getFieldValue(data, ACCOUNT_CUIT);
        } else if (error) {
            console.error('[ventasInformadasCoreActions] wiredAccount', error);
        }
    }

    get accountRecordId() {
        return this.isAccountContext ? this.recordId : null;
    }

    get isAccountContext() {
        return Boolean(this.recordId && String(this.recordId).startsWith(ACCOUNT_KEY_PREFIX));
    }

    get showOriginanteSelector() {
        return !this.isAccountContext;
    }

    /** En Account se oculta descarga; en Crear Venta Informada y portal sigue disponible. */
    get showDescargarPlantilla() {
        return !this.isAccountContext;
    }

    get originanteResumen() {
        if (!this.selectedAccountId) {
            return null;
        }
        const cuit = this.selectedAccountCuit ? ` — CUIT ${this.selectedAccountCuit}` : '';
        return `${this.selectedAccountName || 'Cuenta'}${cuit}`;
    }

    get actionsDisabled() {
        return !this.selectedAccountId;
    }

    get accountFilter() {
        return {
            criteria: [
                {
                    fieldPath: 'RecordType.DeveloperName',
                    operator: 'in',
                    value: ['Distribuidor', 'Obtentor']
                }
            ]
        };
    }

    handleCuitChange(event) {
        this.cuitBusqueda = event.target.value;
    }

    async handleBuscarPorCuit() {
        const cuit = (this.cuitBusqueda || '').trim();
        if (!cuit) {
            this.toast('Ingresá un CUIT', 'warning');
            return;
        }
        this.isSearchingCuit = true;
        try {
            const acc = await buscarCuentaOriginantePorCuit({ cuit });
            if (!acc) {
                this.toast('No se encontró cuenta Distribuidor/Obtentor con ese CUIT.', 'warning');
                return;
            }
            this.applySelectedAccount(acc);
        } catch (e) {
            this.toast(e?.body?.message || 'Error al buscar por CUIT', 'error');
        } finally {
            this.isSearchingCuit = false;
        }
    }

    handleAccountPickerChange(event) {
        const accountId = event.detail.recordId;
        if (!accountId) {
            this.clearSelectedAccount();
            return;
        }
        getCuenta({ recordId: accountId })
            .then(acc => this.applySelectedAccount(acc))
            .catch(e => this.toast(e?.body?.message || 'Error al cargar cuenta', 'error'));
    }

    applySelectedAccount(acc) {
        this.selectedAccountId = acc.Id;
        this.selectedAccountName = acc.Name;
        this.selectedAccountCuit = acc.N_CUIT__c;
    }

    clearSelectedAccount() {
        this.selectedAccountId = null;
        this.selectedAccountName = null;
        this.selectedAccountCuit = null;
    }

    getImporter() {
        return this.template.querySelector('c-ventas-import-from-csv');
    }

    handleNuevaVenta() {
        this.getImporter()?.openVentaModal();
    }

    handleDescargarPlantilla() {
        this.getImporter()?.downloadClick();
    }

    handleImportar() {
        this.getImporter()?.openModal();
    }

    toast(message, variant, title = 'Ventas Informadas') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}