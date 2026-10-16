import { LightningElement, track, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';

// Importar el ID del usuario actual en sesión
import USER_ID from '@salesforce/user/Id';

// Campos del Usuario que requerimos
import USER_NAME_FIELD from '@salesforce/schema/User.Name';
import CONTACT_ACCOUNT_NAME_FIELD from '@salesforce/schema/User.Contact.Account.Name';
import ARPOV_LOGO from '@salesforce/resourceUrl/ArpovLogoRegalia';

export default class Landing_Productor_Regalia extends NavigationMixin(LightningElement) {

    // Propiedades internas dinámicas
    logoUrl = ARPOV_LOGO;
    userName = '';
    userInitials = '';
    currentContext = ''; // Almacenará el nombre de la cuenta

    @track activeTab = 'inicio';
    @track isProfileMenuOpen = false;
    @track isDeclaracionesMenuOpen = false; // Control del nuevo menú desplegable

    // Traer los datos del usuario logueado automáticamente mediante Wire Service
    @wire(getRecord, { 
        recordId: USER_ID, 
        fields: [USER_NAME_FIELD, CONTACT_ACCOUNT_NAME_FIELD] 
    })
    wiredUser({ error, data }) {
        if (data) {
            this.userName = getFieldValue(data, USER_NAME_FIELD) || 'Usuario ArPOV';
            this.calculateInitials(this.userName);
            const accountName = getFieldValue(data, CONTACT_ACCOUNT_NAME_FIELD);
            this.currentContext = accountName ? accountName.toUpperCase() : 'SIN CONTEXTO DE CUENTA';
        } else if (error) {
            console.error('Error cargando datos de usuario en ArPOV:', error);
            this.userName = 'Usuario Invitado';
            this.userInitials = 'UI';
            this.currentContext = 'PORTAL ARPOV';
        }
    }

    // Lógica para procesar el nombre y sacar las iniciales
    calculateInitials(name) {
        if (!name) return;
        const parts = name.trim().split(' ');
        if (parts.length > 1) {
            this.userInitials = (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
        } else if (parts.length === 1) {
            this.userInitials = parts[0].substring(0, 2).toUpperCase();
        }
    }

    // Métodos Getter para evaluar dinámicamente las clases CSS activas
    get inicioClass() {
        return this.activeTab === 'inicio' ? 'nav-item active' : 'nav-item';
    }

    // Si el tab activo es cualquiera de los dos submenús, el padre "DECLARACIONES" se mantiene iluminado
    get declaracionesClass() {
        return (this.activeTab === 'uso-propio' || this.activeTab === 'semilla-fiscalizada') ? 'nav-item active' : 'nav-item';
    }

    // Getters de renderizado condicional de vistas
    get isInicioActive() {
        return this.activeTab === 'inicio';
    }

    get isUsoPropioActive() {
        return this.activeTab === 'uso-propio';
    }

    get isSemillaFiscalizadaActive() {
        return this.activeTab === 'semilla-fiscalizada';
    }

    // Getters para clases dinámicas de los dropdowns
    get profileMenuClass() {
        return this.isProfileMenuOpen ? 'profile-dropdown open' : 'profile-dropdown';
    }

    get declaracionesMenuClass() {
        return this.isDeclaracionesMenuOpen ? 'nav-dropdown open' : 'nav-dropdown';
    }

    // Navegar de vuelta al Inicio al hacer click en el Logo
    navigateToHome() {
        this.activeTab = 'inicio';
        this.isDeclaracionesMenuOpen = false;
        this.isProfileMenuOpen = false;
    }

    // Alternar apertura del menú de Declaraciones
    toggleDeclaracionesMenu(event) {
        event.preventDefault();
        this.isDeclaracionesMenuOpen = !this.isDeclaracionesMenuOpen;
        this.isProfileMenuOpen = false; // Cerrar el de perfil por si estaba abierto
    }

    // Toggle para desplegar/cerrar el menú de perfil
    toggleProfileMenu() {
        this.isProfileMenuOpen = !this.isProfileMenuOpen;
        this.isDeclaracionesMenuOpen = false; // Cerrar el de navegación por si estaba abierto
    }

    // Controlar el cambio de tabs (ahora maneja las opciones del submenú)
    handleTabNavigation(event) {
        event.preventDefault();
        const selectedTab = event.currentTarget.dataset.tab;

        // Si el usuario hace clic en el tab que ya está activo, forzamos la recarga del componente
        if (this.activeTab === selectedTab) {
            this.activeTab = ''; // Reseteamos temporalmente
            setTimeout(() => {
                this.activeTab = selectedTab; // Lo reactivamos en el próximo tick
            }, 0);
        } else {
            this.activeTab = selectedTab;
        }

        this.isDeclaracionesMenuOpen = false;

        this.dispatchEvent(new CustomEvent('tabchange', {
            detail: { tab: selectedTab }
        }));
    }

    // Manejar opciones del menú de perfil
    handleMenuOption(event) {
        event.preventDefault();
        this.isProfileMenuOpen = false;
        const pageName = event.target.dataset.page; 

        switch (pageName) {
            case 'editProfile':
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { pageName: 'editarperfil' }
                });
                break;
            case 'Home':
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { pageName: 'Home' }
                });
                break;
            default:
                break;
        }
    }

    // Simular el cierre de sesión
    handleLogout(event) {
        const communityBaseUrl = window.location.origin;
        const logoutUrl = `${communityBaseUrl}/secur/logout.jsp`;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: logoutUrl }
        }, true);
    }
}