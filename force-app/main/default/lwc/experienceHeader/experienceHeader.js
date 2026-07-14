import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import MY_LOGO from '@salesforce/resourceUrl/SembraEvolucionLogo';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import CONTACT_ID_FIELD from '@salesforce/schema/User.ContactId';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Contact.Account.Name';
import networkId from '@salesforce/community/Id';
import basePath from '@salesforce/community/basePath';
import PRODUCTOR_URL from '@salesforce/label/c.ProductorCommunityUrl';
export default class ExperienceHeader extends NavigationMixin(LightningElement) {

    @track isSalesforce = true; // Cambiar a false para el otro header
    userId = USER_ID;
    userName;
    accountName;
    contactId;
    logoUrl = MY_LOGO;
    productorUrl;

   navItems = [
        {
            label: 'licencias',
            hasSubmenu: true,
            submenu: [
                { label: 'consulta de licencias', url:  basePath +'/consulta-de-licencias-del-productor' },//crearCompra
                { label: 'mis licencias', url:  basePath +'/licenciaslistcustom' }//CompraHTListProductor
            ]
        },
        {
            label: 'Ventas SF',
            hasSubmenu: true,
            submenu: [
                { label: 'ventas informadas procesadas', url:  basePath +'/ventas-informadas-procesadas' },//crearCompra
                { label: 'ventas informadas sin procesar', url:  basePath +'/ventas-informadas-sin-procesar' }//CompraHTListProductor
            ]
        },
        {
            label: 'Ventas HT',
            hasSubmenu: true,
            submenu: [
                { label: 'vender ht', url:  basePath +'/formularionuevaventaht' },//crearCompra
                //{ label: 'todas las ventas ht', url: 'todaslascompras' }//CompraHTListProductor
                { label: 'todas las ventas ht', url: basePath +'/htlistcustom' }//CompraHTListProductor
            ]
            
        },
        
        {
            label: 'facturacion',
            hasSubmenu: false,
            url: basePath +'/mis-facturas'
        },
       
        {
            label: 'mis clientes',
            hasSubmenu: false,
            url: basePath +'/misclientes'
        }
    ];
    
    connectedCallback() {
     //QA = /SembraEvolucion Prod = /Productores/s;
      const BaseUrl = window.location.origin + PRODUCTOR_URL;
        console.log(BaseUrl);
        this.productorUrl = BaseUrl
    }

    clic(event){
        event.preventDefault();
        var urlActual = event.target.getAttribute('href');
        const beforeSlash = `${basePath}`.substring(0, `${basePath}`.indexOf('/s') + 1);
        const communityUrl = `https://${location.host}${beforeSlash}`;
        console.log(communityUrl);
        if(urlActual != null){
            var newUrl = communityUrl+'s/'+urlActual;
        }
        else {
            var newUrl = communityUrl+'s/';
        }
        window.open(newUrl,'_self');
        window.history.pushState({},'', newUrl);
    }

    handleCommunityLogout() {
            const communityBaseUrl = window.location.origin;
            const logoutUrl = `${communityBaseUrl}/secur/logout.jsp`;
    
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: logoutUrl
                }
            },
            true // Reemplaza la entrada actual en el historial del navegador
            );
        }
    
   // Paso 1: traemos User con su ContactId
    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD, CONTACT_ID_FIELD] })
    userDetails({ error, data }) {
        if (data) {
            this.userName = getFieldValue(data, NAME_FIELD);
            this.contactId = getFieldValue(data, CONTACT_ID_FIELD);
        } else if (error) {
            console.error('Error fetching user details:', error);
        }
    }

    // Paso 2: si existe contactId, traemos Account.Name
    @wire(getRecord, { recordId: '$contactId', fields: [ACCOUNT_NAME_FIELD] })
    contactDetails({ error, data }) {
        if (data) {
            this.accountName = getFieldValue(data, ACCOUNT_NAME_FIELD);
        } else if (error) {
            console.error('Error fetching contact/account details:', error);
        }
    }



    handleNavigate(event) {
        event.preventDefault(); // Evita el comportamiento por defecto del enlace
        const pageName = event.target.dataset.page; // Obtiene el valor de data-page

        switch (pageName) {
            case 'editProfile':
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: {
                       pageName: 'editarperfil'
                    }
            });
            break;
            default:
                // Manejar otros casos o un valor por defecto
                break;
        }

    }

}