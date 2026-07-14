import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import MY_LOGO from '@salesforce/resourceUrl/SembraEvolucionLogo';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import CONTACT_ID_FIELD from '@salesforce/schema/User.ContactId';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Contact.Account.Name';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import networkId from '@salesforce/community/Id';
import basePath from '@salesforce/community/basePath';
import COMERCIO_URL from '@salesforce/label/c.ComercioCommunityUrl';
export default class HeaderComponenteSembraEvolucion extends NavigationMixin(LightningElement) {

    @track isSalesforce = true; // Cambiar a false para el otro header
    userId = USER_ID;
    userName;
    accountName;
    contactId;
    comercioUrl;
    profileName;
    logoUrl = MY_LOGO;

   navItems = [
        {
            label: 'licencias',
            hasSubmenu: false,
            url: 'licenciaslistcustomproductor'
        },
         {
            label: 'movimientos de ht',
            hasSubmenu: false,
            url: 'movimientos-ht'
        },
        {
            label: 'mis compras',
            hasSubmenu: true,
            submenu: [
                { label: 'comprar', url: 'FormularioNuevaVentaHT' },//crearCompra
                { label: 'todas mis compras', url: 'comprahtlistproductor' },//CompraHTListProductor
                { label: 'mis facturas', url: 'facturacion' }
            ]
        },
        {
            label: 'precertificacion',
            hasSubmenu: true,
            submenu: [
                { label: 'mis pph', url: `iniciar-pph`},
                { label: 'mis establecimientos', url: 'misestablecimientos' }
            ]
        },
        {
            label: 'cuenta granaria',
            hasSubmenu: false,
            url: 'cuentagranarianew'//cuentaGranariaNew
        },
        
        // {
        //     label: 'Cuenta corriente',
        //     hasSubmenu: false,
        //     url: 'cuenta-corriente'
        // },
        {
            label: 'cesiones',
            hasSubmenu: false,
            url: 'miscesiones'
        }
    ];

    connectedCallback() {
      // QA= SembraEvolucionComercio Prod = /Comercios/s';
      const BaseUrl = window.location.origin + COMERCIO_URL;
     // const BaseUrl = window.location.origin + basePath;
        console.log(BaseUrl);
        this.comercioUrl = BaseUrl
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
    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD, CONTACT_ID_FIELD, PROFILE_NAME_FIELD] })
    userDetails({ error, data }) {
        if (data) {
            this.userName = getFieldValue(data, NAME_FIELD);
            this.contactId = getFieldValue(data, CONTACT_ID_FIELD);
             this.profileName = getFieldValue(data, PROFILE_NAME_FIELD);
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
    // 👇 Getter para validar el perfil
    get isDistribuidor() {
        return this.profileName === 'Distribuidor';
    }

}