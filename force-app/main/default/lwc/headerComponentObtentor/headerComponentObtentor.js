import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import MY_LOGO from '@salesforce/resourceUrl/SembraEvolucionLogo';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import getListViewIdByName from '@salesforce/apex/headerComponentObtentorController.getListViewIdByName';
import getDynamicMenu from '@salesforce/apex/headerComponentObtentorController.getDynamicMenu';
export default class HeaderComponentObtentor extends NavigationMixin(LightningElement) {

    @track isSalesforce = true; 
    userId = USER_ID;
    userName;
    logoUrl = MY_LOGO;

  navItems = [];

    @wire(getDynamicMenu)
    wiredMenu({ data, error }) {
        if (data) {
            this.navItems = data;
        } else if (error) {
            console.error('Error loading menu:', error);
        }
    }

    clic(event){
        event.preventDefault();
        var urlActual = event.target.getAttribute('href');
        const substringToCheck = "Name:";
        if(urlActual != null && urlActual.includes(substringToCheck)){
            var Name = urlActual.split('Name:')[1];
            var url =  urlActual.split('Name:')[0];
            getListViewIdByName({listViewName:Name}).then(result => {
                urlActual = url+result;
                var newUrl = window.location.origin+'/Obtentores/s/'+urlActual;
                window.open(newUrl,'_self');
                window.history.pushState({},'', newUrl);
            });
        }
        else if(urlActual != null){
            var newUrl = window.location.origin+'/Obtentores/s/'+urlActual;
        }
        else {
            var newUrl = window.location.origin+'/Obtentores/s';
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
    
    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD] })
    userDetails({ error, data }) {
        if (data) {
            this.userName = getFieldValue(data, NAME_FIELD);
        } else if (error) {
            console.error('Error fetching user details:', error);
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