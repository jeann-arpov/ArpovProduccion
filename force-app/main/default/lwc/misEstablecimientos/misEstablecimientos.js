import { LightningElement, track, api } from 'lwc';
import getEstablecimientos from '@salesforce/apex/misEstablecimientosController.getEstablecimientos';
import {reduceErrors} from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { doRequest } from 'c/utils';
import icons from 'c/icons';

const COLUMNS = [
    {
      label: 'NOMBRE DEL ESTABLECIMIENTO',
      fieldName: 'link',
      type: 'url',
      typeAttributes: {
        label: { fieldName: 'Name' },
        target: '_self'
      }
    },
    {label: 'COORDENADAS(LATITUD)', fieldName: 'Coordenadas__Latitude__s', fixedWidth: 400, hideDefaultActions: true},
    {label: 'COORDENADAS(LONGITUD)', fieldName: 'Coordenadas__Longitude__s', fixedWidth: 400, hideDefaultActions: true}
];

export default class MisEstablecimientos extends LightningElement {
    @api type;
    @track vencimientos = [];
    columns = COLUMNS;
    Name = 'Todos';
    

    @track sortBy = 'fecha';
    @track sortDirection = 'desc';
    @track searchTerm = '';
    @track totalRegistros = 0; // <<--- Nuevo
    @track NameSelect = '';
    

    pageSize = 10;
    currentPage = 1;
    @track filteredEstablecimientos = [];
    data = [];


    icons = {
        seed: icons.pph.seed
    };
    
    initialized = false;
    loading = false;

    async init() {
        this.initialized = true;

        await doRequest.call(this, async _ => {
            this.data = await getEstablecimientos();
            this.data = this.data.map(row => ({
            ...row,
            link: `/establecimiento/${row.Id}/${row.Name}`
            }));
            this.updatePage();
        });
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

        this.filteredEstablecimientos = filtered;
        this.totalRegistros = filtered.length; // <<--- Aquí se actualiza el contador
        this.currentPage = 1;
    }

    
        updatePage() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        const establecimientos = this.data.slice(start, end);
        this.filteredEstablecimientos = establecimientos;
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