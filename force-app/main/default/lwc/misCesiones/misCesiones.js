import { LightningElement, track, api } from 'lwc';
import getCesiones from '@salesforce/apex/misCesionesController.getCesiones';
import {reduceErrors} from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { doRequest } from 'c/utils';
import icons from 'c/icons';
import { NavigationMixin } from 'lightning/navigation';

const COLUMNS = [
    {
        label: 'FECHA',
        fieldName: 'fechaFormateada',
        fixedWidth: 150,
        hideDefaultActions: true
    },
    {
        label: 'CULTIVO',
        fieldName: 'Cultivo',
        fixedWidth: 190,
        hideDefaultActions: true
    },
    {
        label: 'Cesión',
        fixedWidth: 250,
        fieldName: 'link',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_self'
        }
    },
    {
        label: 'CEDENTE',
        fieldName: 'Cedente',
        fixedWidth: 200,
        hideDefaultActions: true
    },
    {
        label: 'TIPO DE CESIÓN',
        fieldName: 'Tipo_de_Cesion__c',
        fixedWidth: 200,
        hideDefaultActions: true
    },
    {
        label: 'ESTADO',
        fieldName: 'Estado__c',
        fixedWidth: 200,
        hideDefaultActions: true
    },
    {
        label: 'VARIEDADES',
        fieldName: 'Variedades__c',
        fixedWidth: 250,
        hideDefaultActions: true
    }
];

export default class MisCesiones extends NavigationMixin(LightningElement) {
    @api type;
    @track vencimientos = [];
    columns = COLUMNS;
    cultivos;
    Estados;
    TipoCesiones;
    cultivo = 'Todos';
    Estado = 'Todos';
    TipoCesion = 'Todos';

    

    @track sortBy = 'fecha';
    @track sortDirection = 'desc';
    @track searchTerm = '';
    @track totalRegistros = 0; // <<--- Nuevo
    @track CultivoSelect = '';
    @track selectedCultivo = '';
    

    pageSize = 10;
    currentPage = 1;
    @track filteredCesiones = [];
    data = [];


    icons = {
        seed: icons.pph.seed
    };
    
    initialized = false;
    loading = false;

    async init() {
        this.initialized = true;

        await doRequest.call(this, async _ => {
            this.data = await getCesiones();
            console.log(this.data);

            // Inicializamos los rows con link vacío
            this.data = this.data.map(row => {
                const safeName = row.Name
                    ? row.Name.toLowerCase().trim().replace(/\s+/g, '').replace(/[^a-z0-9\-]/g, '')
                    : '';

                // 🔹 Formatear fecha a dd/MM/yyyy
                let fechaFormateada = '';
                if (row.CreatedDate) {
                    const fecha = new Date(row.CreatedDate);
                    const dia = String(fecha.getDate()).padStart(2, '0');
                    const mes = String(fecha.getMonth() + 1).padStart(2, '0');
                    const anio = fecha.getFullYear();
                    fechaFormateada = `${dia}/${mes}/${anio}`;
                }

                const baseRow = {
                    ...row,
                    link: '',
                    Cedente: row.Cuenta_Cedente__r?.Name || '',
                    Cultivo: row.Cultivo__r?.Name || '',
                    fechaFormateada: fechaFormateada
                };

                const pageRef = {
                    type: 'comm__namedPage',
                    attributes: { name: 'Cesion_HT_Detail__c' },
                    state: { recordId: row.Id, recordName: safeName }
                };

                this[NavigationMixin.GenerateUrl](pageRef).then(url => {
                    baseRow.link = url;
                    this.data = [...this.data];
                    this.updatePage();
                });

                return baseRow;
            });

            

            // Armar filtros
            const cultivos = [{ label: 'Cultivo: Todos', value: 'Todos' }];
            const Estados = [{ label: 'Estado: Todos', value: 'Todos' }];
            const TipoCesiones = [{ label: 'Tipo de Cesion: Todos', value: 'Todos' }];

            this.data.forEach(element => {
                if (element.Cultivo && !cultivos.some(o => o.value == element.Cultivo))
                    cultivos.push({ label: `Cultivo: ${element.Cultivo}`, value: element.Cultivo });
                if (element.Estado__c && !Estados.some(o => o.value == element.Estado__c))
                    Estados.push({ label: `Estado: ${element.Estado__c}`, value: element.Estado__c });
                if (element.Tipo_de_Cesion__c && !TipoCesiones.some(o => o.value == element.Tipo_de_Cesion__c))
                    TipoCesiones.push({ label: `Tipo de Cesion: ${element.Tipo_de_Cesion__c}`, value: element.Tipo_de_Cesion__c });
            });

            this.cultivos = cultivos;
            this.Estados = Estados;
            this.TipoCesiones = TipoCesiones;
            this.updatePage();
        });
    }

     handleCultivoSelect(event){
        this.cultivo = event.target.value;
        this.filteredCesiones = this.cultivo == 'Todos' ? this.data : this.data.filter(v => v.Cultivo__r.Name == this.cultivo); 
        this.totalRegistros = this.filteredCesiones.length;
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        const Cesiones = this.filteredCesiones.slice(start, end);
        this.filteredCesiones = Cesiones;
    }

    handleTipoCesion(event){
        this.TipoCesion = event.target.value;
        this.filteredCesiones = this.TipoCesion == 'Todos' ? this.data : this.data.filter(v => v.Tipo_de_Cesion__c == this.TipoCesion); 
        this.totalRegistros = this.filteredCesiones.length;
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        const Cesiones = this.filteredCesiones.slice(start, end);
        this.filteredCesiones = Cesiones;
    }

    handleEstadoSelect(event){
        this.Estado = event.target.value;
        this.filteredCesiones = this.Estado == 'Todos' ? this.data : this.data.filter(v => v.Estado__c == this.Estado); 
        this.totalRegistros = this.filteredCesiones.length;
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        const Cesiones = this.filteredCesiones.slice(start, end);
        this.filteredCesiones = Cesiones;
    }




    renderedCallback() {
        if (!this.initialized) this.init();
    }


    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
            mode: 'sticky'
        }));
    }

    //reemplazando vencimientos por data, podemos hacer que los totales sean dinámicos según que facturas se esten visualizando
    

    handleOnSort(event){
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData();
    }

    sortData() {
        const parseData = JSON.parse(JSON.stringify(this.data));

        const keyValue = (a) => {
            return a[this.sortBy];
        };

        const isReverse = this.sortDirection === 'asc' ? 1: -1;

        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });

        this.data = parseData;
    } 


    handleNameSelect(event){
        // this.NameSelect = event.target.value;
        // this.filteredNames = this.Name == 'Todos' ? this.vencimientos : this.vencimientos.filter(v => v.cultivo == this.cultivo);
        this.updatePage();
    }

    // Aplicar filtros y búsqueda
    
    applyFilters() {
        let filtered = [...this.data];

        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            filtered = filtered.filter(l =>
                (l.Name && l.Name.toLowerCase().includes(term)) 
            );
        }
        this.filteredCesiones = filtered;
        this.totalRegistros = filtered.length; // <<--- Aquí se actualiza el contador
        this.currentPage = 1;
    }

    
    updatePage() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        const Cesiones = this.data.slice(start, end);
        this.filteredCesiones = Cesiones;
        this.totalRegistros = this.data.length;
    } 

   get disablePrev() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= Math.ceil(this.data.length / this.pageSize);
    }

    handlePrev() {
        if (!this.disablePrev) {
            this.currentPage--;
            this.updatePage();
        }
    }

    handleNext() {
        if (!this.disableNext) {
            this.currentPage++;
            this.updatePage();
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        if(this.searchTerm.length > 0){
            this.applyFilters();
        }
        else {
            this.updatePage();
        }
    }
}