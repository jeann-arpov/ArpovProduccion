import { LightningElement,wire } from 'lwc';
import getButtonData from '@salesforce/apex/SolicitarLicencia.getButtonData';
import searchAccounts from '@salesforce/apex/SolicitarLicencia.searchAccounts';
import generateToken from '@salesforce/apex/CustomJWTSigner.CustomJWTSigner';
import generateTokenLic from '@salesforce/apex/CustomJWTSigner.CustomJWTSignerLicencias';
import getUrl from '@salesforce/apex/SolicitarLicencia.getUrl';
import { errorEvent,validateInputs,doRequest } from 'c/utils';
import { NavigationMixin,CurrentPageReference } from 'lightning/navigation';
import uId from '@salesforce/user/Id';
import { getRecord,getFieldValue } from "lightning/uiRecordApi";
import CONTACT_ID from "@salesforce/schema/User.ContactId";
import singleNewLicenseRequestJWTSigner from '@salesforce/apex/CustomJWTSigner.singleNewLicenseRequestJWTSigner';


export default class SolicitarLicenciaButton extends NavigationMixin(LightningElement) {
    showModal = false;
    loading = false;
    marcas = [];
    type;
    marca;
    isPortalComercio;
    isPortalObtentor;
    licenceType;
    licenceTypes = [{ value: 'Comercio',label: 'Comercio' },{ value: 'Productor',label: 'Productor' }];
    licencias;
    currentUserId = uId;
    JWToken;
    currentContactId;
    url;

    @wire(generateToken,{ userId: '$currentUserId',url: window.location.href,contactId: '$currentContactId' })
    wiredAccountId({ error,data }) {
        if (data) {
            try {
                this.JWToken = data;
            } catch (e) {
                console.log('catch ' + e);
            }
        } else if (error) {
            this.error = error;
            console.log(error);
        }
    }

    @wire(getUrl, {})
    wiredGetUrl({error, data}){
        if (data) {
            console.log(data);
            this.url = data
        } else if (error) {
            this.error = error;
            console.log(error);
        }
    }
    @wire(getRecord,{ recordId: '$currentUserId',fields: [CONTACT_ID] })
    wiredContactId({ error,data }) {
        if (data) {
            try {
                this.currentContactId = data.fields.ContactId.value
                console.log('MI ID: ' + this.currentContactId);
                //this.generateTokenLic();
            } catch (e) {
                console.log('catch ' + e);
            }
        } else if (error) {
            this.error = error;
            console.log(error);
        }
    }

    handleSolicitarLicencia(event) {
        this.isLoading = true;
        const licenseId = event.currentTarget.dataset.id;
        console.log(JSON.stringify(licenseId));
        singleNewLicenseRequestJWTSigner({userId: this.currentUserId, contactId: this.currentContactId})
        .then(response => {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: this.url + '/NewLicenseRequest' + '?token=' + response + '&url=' + window.location.href
                }
            },
                true // Replaces the current page in your browser history with the URL
            );
        })
        .catch(error => console.log(error))
    }

    // connectedCallback() {
    //     this.generateTokenLic();
    // }

    generateTokenLic() {
        console.log('contactId: ' + this.currentContactId);

        generateTokenLic({ userId: this.currentUserId,url: window.location.href,contactId: this.currentContactId })
            .then(data => {
                console.log('data' + data);
            }).catch(e => {
                console.log('Error output: '+JSON.stringify(e));
                console.log(e);
            })
    }

    handleSolicitarLicencia(event) {
        this.isLoading = true;
        const licenseId = event.currentTarget.dataset.id;
        console.log(JSON.stringify(licenseId));
        singleNewLicenseRequestJWTSigner({userId: this.currentUserId, contactId: this.currentContactId})
        .then(response => {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: this.url + '/NewLicenseRequest' + '?token=' + response + '&url=' + window.location.href
                }
            },
                true // Replaces the current page in your browser history with the URL
            );
        })
        .catch(error => console.log(error))
    }


    async init() {
        this.doRequest = doRequest.bind(this);
        this.initialized = true;

        console.log('EL USERID ::: ' + this.currentUserId);



        this.doRequest(async _ => {
            const data = await getButtonData();
            console.log(data);
            this.marcas = data.marcas.filter(m => m.Nombre_Obtentor__c != 'LDC').map(m => ({ value: m.Id,label: m.Nombre_Obtentor__c,cuit: m.Parent ? m.Parent.N_CUIT__c : m.N_CUIT__c }));
            this.isPortalComercio = data.isPortalComercio;
            this.isPortalObtentor = data.isPortalObtentor;
            this.licencias = data.licencias;


            if (this.isPortalComercio) {
                this.account = { id: null,sObjectType: 'Account',icon: 'standard:account',title: 'Gestionar Licencia para mí',subtitle: '',record: null };
            } else if (this.isPortalObtentor) {
                this.marca = this.marcas[0].value;
            } else {
                this.licenceType = 'Productor';
            }
        });
    }

    @wire(CurrentPageReference)
    CurrentPageReference;

    redirectToSolicitarLicenciaWithToken() {
        sessionStorage.setItem('TOKEN::: ',this.JWToken)
        sessionStorage.setItem('USER ID::: ',this.currentUserId)

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: this.url + '?token=' + this.JWToken + '&url=' + window.location.href
            }
        },
            true // Replaces the current page in your browser history with the URL
        );

    }



    openModal(e) {
        this.showModal = true;
        if (!this.initialized) this.init();
    }

    closeModal(e) {
        this.showModal = false;
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }

    validate() {
        return validateInputs(this.template);
    }

    hasLicence(datos) {
        return this.licencias.find(l => l.Cuenta_Obtentor__r.N_CUIT__c == datos.cuit) != null;
    }

    redirectToSolicitarLicencia() {
        const type = this.type;
        const marca = this.marca;
        const licenceType = this.licenceType;

        if (type == 'e3') {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: 'https://phazp0897appwebgui.azurewebsites.net/'
                }
            },
                true // Replaces the current page in your browser history with the URL
            );
        } else if (type == 'hb4') {
            this.onError('Próximamente estará disponible');
        } else {
            const datos = this.marcas.find(m => m.value == marca);
            const validCuits = this.isPortalComercio ? this.cuitsPortalComercio : this.cuitsOtrosPortales;
            const tercero = this.template.querySelector('c-lookup')?.selection[0];

            if (this.isPortalComercio && tercero && tercero.record && this.hasLicence(datos) == false) return this.onError('No posee una licencia de comercio con la marca seleccionada para gestionar a un tercero');

            const state = {
                marca,
                type,
                licenceType
            };

            if ((this.isPortalComercio || this.isPortalObtentor) && tercero && tercero.id) state.tercero = tercero.id;

            if (licenceType == 'Comercio' && ['30646328450','30707285563','33710831659'].includes(datos.cuit)) {
                return this.onError(`No se pueden gestionar licencia de comercio para esta marca`);
            }

            if (!validCuits.includes(datos.cuit)) return this.onError(`Error: ${datos.label} no gestiona licencias para aporte genético`);
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    pageName: 'solicitar-licencia'
                },
                state
            });
        }
    }

    marcaChanged(e) {
        this.marca = e.target.value;
    }

    licenceTypeChanged(e) {
        this.licenceType = e.target.value;
    }

    selectLicenseType(e) {
        this.type = e.target.closest('lightning-layout-item').dataset.type;
    }

    get selectLicenseClass() {
        return "license-type slds-m-bottom_x-large" + (this.type ? ' ' + this.type : '');
    }

    get shouldShowMarcas() {
        return this.type == 'genetico' && !this.isPortalObtentor;
    }

    get cantContinue() {
        return !(this.type != null && (this.type != 'genetico' || (this.marca && this.licenceType)));
    }

    get shouldShowTercero() {
        return this.type == 'genetico' && (this.isPortalComercio || this.isPortalObtentor);
    }

    get shouldShowTipoLicencia() {
        return this.isPortalComercio || this.isPortalObtentor;
    }

    get cuitsPortalComercio() {
        return ['30616275905','30646328450','30707285563','33710831659','30517486678'];
    }

    get cuitsOtrosPortales() {
        return ['30616275905','30646328450','30707285563','33710831659','30517486678'];
    }

    async search(event) {
        const lookup = event.target;
        await searchAccounts(event.detail).then(res => lookup.setSearchResults(res)).catch(e => this.onError(e));
    }

    terceroSelected(event) {
        const selection = event.target.getSelection();
        this.tercero = selection.length ? selection[0].record : null;
    }

    setDefaultSelection(e) {
        if (e.target && e.target.classList.contains('content') && this.template.querySelector('c-lookup') && this.template.querySelector('c-lookup').selection.length == 0) {
            this.template.querySelector('c-lookup').selection = this.account;
        }
    }
}