import { LightningElement, track, api, wire } from 'lwc';
import getEstablecimientos from '@salesforce/apex/EstablecimientosMap.getEstablecimientos';
import getAccountId from '@salesforce/apex/EstablecimientosMap.getAccountId';
import insertEstablecimiento from '@salesforce/apex/EstablecimientosMap.insertEstablecimiento';
import { doRequest, errorEvent } from 'c/utils';
import { NavigationMixin } from 'lightning/navigation';

export default class EstablecimientosMap extends NavigationMixin(LightningElement) {

    markers;

    initialized = false;
    loading = false;
    modal = false;
    @track searchKey = '';
    @track records = [];
    @track selectedRecord;
    @track SelectedNameEstablecimiento;
    @track SelectedLatitud;
    @track SelectedLongitud;
    @track SelectedVigente;
    @track modalmsj = false;
    @track mensaje;
    picklistOptions = [];
    selectedProductor;
    map;
    longitude;
    latitude;

    
    async init(){
        this.initialized = true;
        await doRequest.call(this, async _ => {
            const establecimientos = await getEstablecimientos();
            const  accountId = await getAccountId();
            this.selectedProductor = accountId;

            console.log(establecimientos);
            this.markers = establecimientos.filter(est => est.Coordenadas__Latitude__s).map(est => {
                const marker = {title: est.Name};

                marker.location = {Latitude: (est.Coordenadas__Latitude__s + ''), Longitude: (est.Coordenadas__Longitude__s + '')};
                return marker;
            });
        });
    }


    get mapCoodinates() {
        if (this.latitude != undefined) return this.latitude.toFixed(2) + ', ' + this.longitude.toFixed(2);
        return "Seleccionar Punto de lote";
    }

    get coordinatesClass() {
        return "coordinates" + (this.latitude != undefined ? '' : ' black');
    }

    validateCoordinates(longitude, latitude){
        return Math.sign(longitude) == -1 && Math.sign(latitude) == -1;
    }
    

    showMap(event) {
        this.template.querySelector('c-map').show(this.updateLocation.bind(this));
    }

    
    updateLocation(data, map) {
        map.hide();
        if(this.validateCoordinates(data.longitude, data.latitude)){
            this.longitude = data.longitude;
            this.latitude = data.latitude;
            //sin esto queda como required faltante
            this.template.querySelector('.coordinates').value = this.mapCoodinates;
            this.template.querySelector('.coordinates').setCustomValidity('');
            this.template.querySelector('.coordinates').reportValidity();
            this.template.querySelector('c-map').hide();
        }else{
            this.dispatchEvent(errorEvent(new Error('Las coordenadas deben ser negativas')));
        }
    }

    // Manejador para cambios
     handleNameChange(event) {
        this.SelectedNameEstablecimiento = event.detail.value;
    }

     handleLatitudChange(event) {
        this.SelectedLatitud = event.detail.value;
    }

     handleLongitudChange(event) {
        this.SelectedLongitud = event.detail.value;
    }

     handleVigenteChange(event) {
        this.SelectedVigente = event.target.checked;
    }


    closeModal(){
        this.modal = false;
        this.modalmsj = false;
        this.clearSelection();
    }

    @api label = 'Productor';
    @api placeholder = 'Escribe para buscar...';
    @api sObjectApiName = 'Account'; // Cambia según el objeto
    @track searchKey = '';
    @track searchResults = [];
    @track selectedRecord;

    handleSearch(event) {
        this.searchKey = event.target.value;
        if (this.searchKey.length > 1) {
            fetchLookupData({ searchKey: this.searchKey, sObjectApiName: this.sObjectApiName })
                .then(result => {
                    this.searchResults = result;
                })
                .catch(error => {
                    console.error('Error en búsqueda:', error);
                });
        } else {
            this.searchResults = [];
        }
    }

    handleSelectLook(event) {
        const recordId = event.currentTarget.dataset.id;
        fetchDefaultRecord({ recordId, sObjectApiName: this.sObjectApiName })
            .then(result => {
                this.selectedRecord = result;
                this.searchResults = [];
                this.searchKey = this.selectedRecord.Name;
            })
            .catch(error => {
                console.error('Error al obtener registro:', error);
            });
    }

    clearSelection() {
        this.selectedRecord = null;
        this.searchKey = '';
    }


    handleSelect(event) {
        const selectedName = event.target.innerText;
        const selected = this.records.find(rec => rec.Name === selectedName);
        this.selectedRecord = selected;
        this.records = [];
    }

    renderedCallback(){
        if(this.initialized == false){
            this.init();
        }
    }

    openModalNew(){
        console.log('show modal');
        this.modal = true;
        this.showMap();
    }

    onError(e){
        this.dispatchEvent(errorEvent(e));
    }

    handleSave(){
        const EstablecimientoData = {
            Name: this.SelectedNameEstablecimiento,
            Coordenadas__Latitude__s: parseFloat(this.latitude),
            Coordenadas__Longitude__s: parseFloat(this.longitude),
            Vigente__c: true,
            Productor__c: this.selectedProductor
        }
        insertEstablecimiento({ fieldMap: EstablecimientoData })
            .then(result => {
                console.log(result);
                this.mensaje = 'Nuevo establecimiento generado con exito';
            })
            .catch(error => {
                this.mensaje = 'Ocurrio un error al generar el nuevo establecimiento';
            });
        
        this.modal = false;
        this.clearSelection();
        this.modalmsj = true;
    }


    openModal() {
        this.template.querySelector('c-modal').show();
    }
}