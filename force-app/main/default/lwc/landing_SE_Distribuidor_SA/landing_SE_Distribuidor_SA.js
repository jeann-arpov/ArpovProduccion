import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
// import getCurrentUserData from '@salesforce/apex/UserControllerComunidad.getCurrentUserData';
import getHTMetricasComercio from '@salesforce/apex/UserControllerComunidad.getHTMetricasComercio';
import getLicenciasContadas from '@salesforce/apex/UserControllerComunidad.getLicenciasContadas';
import generateTokenLic from '@salesforce/apex/CustomJWTSigner.CustomJWTSignerLicencias';
import getUrl from '@salesforce/apex/SolicitarLicencia.getUrl';
import getCalendarioUrl from '@salesforce/apex/UserControllerComunidad.getCalendarioUrl'
import getBolsasObtentorCampaniaActiva from '@salesforce/apex/UserControllerComunidad.getBolsasObtentorCampaniaActiva';
import getBolsasPrimeraMultiplicacionActual from '@salesforce/apex/UserControllerComunidad.getBolsasPrimeraMultiplicacionActual';
import { getRecord } from 'lightning/uiRecordApi';
import uId from '@salesforce/user/Id';
import CONTACT_ID from "@salesforce/schema/User.ContactId";
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import singleNewLicenseRequestJWTSigner from '@salesforce/apex/CustomJWTSigner.singleNewLicenseRequestJWTSigner';

export default class Landing_SE_Distribuidor_SA extends NavigationMixin(LightningElement) {
    iconLicenciasUrl = `${resourcePortal}/resourcePortal/images/icon-licencias.svg`;
    iconVenderHTUrl = `${resourcePortal}/resourcePortal/images/icon-vender-ht.svg`;
    @track hectareasVendidas = 0;
    @track hectareasPendientesDePago = 0;
    @track licenciasAprobadas = 0;
    @track licenciasEnProceso = 0;
    @track bolsasObtentor = 0;
    @track bolsasPrimeraMultiplicacion = 0;

    calendarioUrl;
    currentDate;
    currentContactId;
    currentUserId = uId;
    JWToken;
    url;

    connectedCallback() {
        const today = new Date();
        const day = today.getDate();
        const month = today.getMonth() + 1;
        const year = today.getFullYear();
        this.currentDate = `AL ${day}/${month}/${year}`;
    }

    // Campos HT_Vendidas__c / HT_Facturadas__c en User/Account: deshabilitados por inconsistencias en flows.
    // @wire(getCurrentUserData)
    // wiredUser({ error, data }) {
    //     if (data) {
    //         this.hectareasVendidas = data.HT_Vendidas__c;
    //         this.hectareasPendientesDePago = data.HT_Facturadas__c;
    //     } else if (error) {
    //         console.error('Error al obtener datos del usuario:', error);
    //     }
    // }

    @wire(getHTMetricasComercio)
    wiredHTMetricas({ error, data }) {
        if (data) {
            this.hectareasVendidas = this.formatHT(data.htVendidas);
            this.hectareasPendientesDePago = this.formatHT(data.htPendientesDePago);
        } else if (error) {
            console.error('Error al obtener métricas HT del comercio:', error);
            this.hectareasVendidas = 0;
            this.hectareasPendientesDePago = 0;
        }
    }

    formatHT(value) {
        const n = Number(value);
        return Number.isFinite(n) ? Math.round(n) : 0;
    }

    @wire(getLicenciasContadas)
    wiredLicencias({ error, data }) {
        if (data) {
            this.licenciasAprobadas = data.aprobadas;
            this.licenciasEnProceso = data.enProceso;
        } else if (error) {
            console.error('Error al obtener licencias', error);
        }
    }

    @wire(getRecord, { recordId: uId, fields: [CONTACT_ID] })
    wiredContact({ error, data }) {
        if (data) {
            this.currentContactId = data.fields.ContactId.value;
        } else if (error) {
            console.error('Error al obtener ContactId:', error);
        }
    }

    @wire(getCalendarioUrl)
    wiredUrl({ error, data }) {
        if (data) {
            this.calendarioUrl = data;
        } else if (error) {
            console.error('Error al obtener URL del calendario:', error);
        }
    }

    @wire(getBolsasObtentorCampaniaActiva)
    wiredBolsas({ error, data }) {
        if (data !== undefined) {
            console.log('Bolsas obtentor: ' + JSON.stringify(data) );
            this.bolsasObtentor = data;
        } else if (error) {
            console.error('Error al obtener bolsas:', error);
        }
    }

    @wire(getBolsasPrimeraMultiplicacionActual)
    wiredBolsasPM({ error, data }) {
        if (data !== undefined) {
            console.log('Bolsas licencias: ' + JSON.stringify(data) );
            this.bolsasPrimeraMultiplicacion = data;
        } else if (error) {
            console.error('Error al obtener bolsas PM:', error);
        }
    }

    handleCalendario() {
        if (this.calendarioUrl) {
            window.open(this.calendarioUrl, '_blank');
        } else {
            console.warn('No se encontró la URL del calendario.');
        }
    }

    @wire(getUrl)
    wiredGetUrl({ error, data }) {
        if (data) {
            this.url = data;
        } else if (error) {
            console.error('Error al obtener la URL:', error);
        }
    }

    async handleSolicitarLicencia() {
        try {
            if (!this.currentContactId) {
                console.warn('ContactId no disponible aún');
                return;
            }
            this.isLoading = true;

            const token = await singleNewLicenseRequestJWTSigner({
                userId: this.currentUserId,
                contactId: this.currentContactId
            });

            this[NavigationMixin.Navigate](
                {
                    type: 'standard__webPage',
                    attributes: {
                        url: `${this.url}/NewLicenseRequest?token=${token}&url=${window.location.href}`
                    }
                },
                true // reemplaza la pestaña actual en el historial
            );
        } catch (error) {
            console.error('Error en handleSolicitarLicencia:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleVerLicenciasAprobadas() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'LicenciasListCustom__c'
            },
            state: {
                estado: 'Aprobada'
            }
        });
    }

    handleVerLicenciasEnProceso() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'LicenciasListCustom__c'
            },
            state: {
                estado: 'En Proceso de Aprobación'
            }
        });
    }

    handleVerHTVendidas() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'HTListCustom__c'
            },
            state: {
                estado: 'Pagada'
            }
        });
    }

    handleVerHTFacturadas() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'HTListCustom__c'
            },
            state: {
                estado: 'Facturada'
            }
        });
    }

    handleVenderHT() {
        console.log('Vender HT');
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'FormularioNuevaVentaHT__c'
            },
            state: {
                estado: ''
            }
        });
    }

    handleViewVendidas() {
        console.log('Ver HT Vendidas');
    }

    handleViewFacturadas() {
        console.log('Ver HT Facturadas');
    }

    handleCalendario() {
        if (this.calendarioUrl) {
            window.open(this.calendarioUrl, '_blank');
        } else {
            console.warn('No se encontró la URL del calendario.');
        }
    }

    handleVerbolsasObtentor() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'BolsasObtentorList__c'
            },
            state: {
                estado: ''
            }
        });
    }
    handleVerbolsasPrimeraMultiplicacion() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'BolsasPrimeraMultiplicacionList__c'
            },
            state: {
                estado: ''
            }
        });
    }
}