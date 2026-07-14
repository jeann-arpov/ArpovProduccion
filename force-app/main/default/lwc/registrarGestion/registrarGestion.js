import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';
import obtenerGestiones from '@salesforce/apex/GestionExpedientesController.obtenerGestiones';
import obtenerSiguienteNumero from '@salesforce/apex/GestionExpedientesController.obtenerSiguienteNumero';
import crearGestion from '@salesforce/apex/GestionExpedientesController.crearGestion';
import eliminarGestionApex from '@salesforce/apex/GestionExpedientesController.eliminarGestion';
import TIPO_EXPEDIENTE_FIELD from '@salesforce/schema/Expediente_de_Negativos__c.Tipo_expendiente__c';
import GESTION_OBJECT from '@salesforce/schema/Gestion_Expedientes__c';
import OPERADOR_FIELD from '@salesforce/schema/Gestion_Expedientes__c.Operador__c';
import RESPUESTA_FIELD from '@salesforce/schema/Gestion_Expedientes__c.Respuesta__c';

const PAGE_SIZE = 10;
const RESPUESTA_SOLO_PRI = 'Licencia E3 en gestión';

export default class RegistrarGestion extends NavigationMixin(LightningElement) {
    @api recordId;
    @track mostrarModal = false;
    @track cargando = false;
    @track mostrarError = false;
    @track mensajeError = '';

    @track numeroGestion = '';
    @track celular = '';
    @track medio = '';
    @track inicio = '';
    @track operador = '';
    @track respuesta = '';
    @track comentario = '';
    
    // Timeline data
    @track gestiones = [];
    @track gestionesAgrupadas = [];
    @track mostrarTimeline = true;

    // Paginación
    @track totalGestiones = 0;
    @track registrosCargados = 0;
    @track cargandoMas = false;

    // Wire result reference para refresh
    wiredGestionesResult;

    @track opcionesMedio = [
        { label: 'WhatsApp', value: 'WhatsApp' },
        { label: 'Email', value: 'Email' },
        { label: 'Llamada', value: 'Llamada' }
    ];

    @track opcionesInicio = [
        { label: 'Saliente', value: 'Saliente' },
        { label: 'Entrante', value: 'Entrante' }
    ];

    tipoExpediente = '';
    recordTypeId;
    @track operadorPicklist;
    @track respuestaPicklist;

    @wire(getRecord, { recordId: '$recordId', fields: [TIPO_EXPEDIENTE_FIELD] })
    wiredExpediente({ data }) {
        if (data) {
            this.tipoExpediente = getFieldValue(data, TIPO_EXPEDIENTE_FIELD) || '';
        }
    }

    @wire(getObjectInfo, { objectApiName: GESTION_OBJECT })
    wiredGestionObjectInfo({ data }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: OPERADOR_FIELD })
    wiredOperadorPicklist({ data }) {
        if (data) {
            this.operadorPicklist = data;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: RESPUESTA_FIELD })
    wiredRespuestaPicklist({ data }) {
        if (data) {
            this.respuestaPicklist = data;
        }
    }

    get opcionesOperador() {
        return this.operadorPicklist?.values || [];
    }

    get opcionesRespuesta() {
        if (!this.operador || !this.respuestaPicklist) {
            return [];
        }

        const controllerKey = this.respuestaPicklist.controllerValues[this.operador];
        if (controllerKey === undefined) {
            return [];
        }

        let opciones = this.respuestaPicklist.values.filter(
            (opt) => opt.validFor.includes(controllerKey)
        );

        if (this.tipoExpediente !== 'PRI') {
            opciones = opciones.filter((opt) => opt.value !== RESPUESTA_SOLO_PRI);
        }

        return opciones;
    }

    get respuestaDeshabilitada() {
        return !this.operador || !this.respuestaPicklist;
    }

    // Getter para saber si hay más registros
    get hayMasRegistros() {
        return this.registrosCargados < this.totalGestiones;
    }

    get textoMostrarMas() {
        const restantes = this.totalGestiones - this.registrosCargados;
        return `Mostrar más`;
    }

    // Wire para cargar gestiones
    @wire(obtenerGestiones, { expedienteId: '$recordId', limitSize: PAGE_SIZE, offset: 0 })
    wiredGestiones(result) {
        this.wiredGestionesResult = result;
        if (result.data) {
            this.gestiones = result.data.gestiones;
            this.totalGestiones = result.data.total;
            this.registrosCargados = this.gestiones.length;
            this.agruparGestionesPorFecha();
        } else if (result.error) {
            console.error('Error cargando gestiones:', result.error);
            this.gestiones = [];
            this.gestionesAgrupadas = [];
        }
    }

    /**
     * Abre el modal
     */
    abrirModal() {
        console.log('Abriendo modal...');
        this.mostrarModal = true;
        // Obtener número de gestión del servidor
        this.obtenerNumeroGestion();
        // Bloquear scroll del fondo
        document.body.style.overflow = 'hidden';
    }
    
    /**
     * Obtiene el número de gestión del servidor
     */
    async obtenerNumeroGestion() {
        try {
            const numero = await obtenerSiguienteNumero({ expedienteId: this.recordId });
            this.numeroGestion = numero;
        } catch (error) {
            console.error('Error obteniendo número:', error);
            this.numeroGestion = 'GE-XXXXX';
        }
    }

    /**
     * Cierra el modal
     */
    handleClose() {
        console.log('Cerrando modal...');
        this.mostrarModal = false;
        // Restaurar scroll del fondo
        document.body.style.overflow = '';
        this.limpiarFormulario();
    }

    handleCelularChange(event) {
        let valor = event.target.value.replace(/\D/g, '');
        this.celular = valor;
        event.target.value = valor;
    }

    handleMedioChange(event) {
        this.medio = event.detail.value;
    }

    handleInicioChange(event) {
        this.inicio = event.detail.value;
    }

    handleOperadorChange(event) {
        this.operador = event.detail.value;
        this.respuesta = '';
    }

    handleRespuestaChange(event) {
        this.respuesta = event.detail.value;
    }

    handleComentarioChange(event) {
        this.comentario = event.target.value;
    }

    /**
     * Guarda la gestión en Salesforce
     */
    async guardarGestion() {
        if (!this.validarCampos()) {
            return;
        }
        
        this.cargando = true;
        this.mostrarError = false;
        
        try {
            await crearGestion({
                expedienteId: this.recordId,
                celular: this.celular,
                medio: this.medio,
                tipoGestion: this.inicio,
                operador: this.operador,
                respuesta: this.respuesta,
                comentario: this.comentario
            });
            
            // Refrescar datos desde servidor
            await refreshApex(this.wiredGestionesResult);
            
            this.mostrarToast('Éxito', `Gestión registrada correctamente`, 'success');
            this.handleClose();
            
        } catch (error) {
            console.error('Error guardando gestión:', error);
            this.mostrarError = true;
            this.mensajeError = error.body?.message || 'Error inesperado al guardar la gestión';
        } finally {
            this.cargando = false;
        }
    }
    
    /**
     * Carga más gestiones (paginación)
     */
    async cargarMas() {
        this.cargandoMas = true;
        try {
            const result = await obtenerGestiones({ 
                expedienteId: this.recordId, 
                limitSize: PAGE_SIZE, 
                offset: this.registrosCargados 
            });
            
            // Agregar las nuevas gestiones a las existentes
            this.gestiones = [...this.gestiones, ...result.gestiones];
            this.totalGestiones = result.total;
            this.registrosCargados = this.gestiones.length;
            this.agruparGestionesPorFecha();
        } catch (error) {
            console.error('Error cargando más gestiones:', error);
            this.mostrarToast('Error', 'No se pudieron cargar más gestiones', 'error');
        } finally {
            this.cargandoMas = false;
        }
    }
    
    /**
     * Agrupa gestiones por fecha para el timeline
     */
    agruparGestionesPorFecha() {
        const grupos = {};
        
        this.gestiones.forEach(gestion => {
            const fecha = new Date(gestion.CreatedDate);
            const fechaKey = fecha.toDateString();
            const fechaFormateada = this.formatearFecha(fecha);
            
            if (!grupos[fechaKey]) {
                grupos[fechaKey] = {
                    fecha: fechaFormateada,
                    fechaKey: fechaKey,
                    gestiones: []
                };
            }
            
            // Agregar propiedades de visualización
            const tipoTimeline = this.obtenerTipoTimeline(gestion.Medio__c);
            const gestionConEstilo = {
                id: gestion.Id,
                numeroGestion: gestion.Name,
                celular: gestion.Celular__c,
                medio: gestion.Medio__c,
                inicio: gestion.Tipo_Gestion__c,
                operador: gestion.Operador__c,
                respuesta: gestion.Respuesta__c,
                comentario: gestion.Comentario__c,
                agente: gestion.CreatedBy?.Name || '',
                fecha: gestion.CreatedDate,
                icono: this.obtenerIconoPorMedio(gestion.Medio__c),
                colorIcono: this.obtenerColorPorRespuesta(gestion.Respuesta__c),
                horaFormateada: this.formatearHora(fecha),
                respuestaFormateada: (gestion.Respuesta__c || '').replace('_', ' '),
                subtitulo: this.obtenerSubtitulo(gestion),
                expanded: false,
                expandIcon: 'utility:chevronright',
                ariaHidden: 'true',
                timelineItemClass: 'slds-timeline__item_expandable slds-timeline__item_' + tipoTimeline.type,
                iconContainerClass: 'slds-icon_container ' + tipoTimeline.iconClass + ' slds-timeline__icon'
            };
            
            grupos[fechaKey].gestiones.push(gestionConEstilo);
        });
        
        // Convertir a array y ordenar por fecha (más reciente primero)
        this.gestionesAgrupadas = Object.values(grupos).map(grupo => {
            // Ordenar gestiones dentro del día por hora (más recientes primero)
            grupo.gestiones.sort((a, b) => new Date(b.fecha) - new Date(a.fecha));
            return grupo;
        }).sort((a, b) => 
            new Date(b.fechaKey) - new Date(a.fechaKey)
        );
    }
    
    /**
     * Obtiene ícono según el medio
     */
    obtenerIconoPorMedio(medio) {
        const iconos = {
            'WhatsApp': 'standard:live_chat',
            'Email': 'standard:email', 
            'Llamada': 'standard:log_a_call'
        };
        return iconos[medio] || 'standard:task';
    }

    /**
     * Obtiene tipo de timeline y clase de icono según el medio
     */
    obtenerTipoTimeline(medio) {
        const tipos = {
            'WhatsApp': { type: 'call', iconClass: 'slds-icon-standard-live-chat' },
            'Email': { type: 'email', iconClass: 'slds-icon-standard-email' },
            'Llamada': { type: 'call', iconClass: 'slds-icon-standard-log-a-call' }
        };
        return tipos[medio] || { type: 'task', iconClass: 'slds-icon-standard-task' };
    }

    /**
     * Obtiene la clase CSS del timeline item (con o sin slds-is-open)
     */
    obtenerTimelineItemClass(medio, expanded) {
        const tipoTimeline = this.obtenerTipoTimeline(medio);
        let cls = 'slds-timeline__item_expandable slds-timeline__item_' + tipoTimeline.type;
        if (expanded) {
            cls += ' slds-is-open';
        }
        return cls;
    }

    /**
     * Genera el subtítulo según el medio
     */
    obtenerSubtitulo(gestion) {
        const acciones = {
            'WhatsApp': 'Registró una conversación por WhatsApp',
            'Email': 'Registró un correo electrónico',
            'Llamada': 'Registró una llamada'
        };
        return acciones[gestion.Medio__c] || 'Registró una gestión';
    }
    
    /**
     * Obtiene color según la respuesta
     */
    obtenerColorPorRespuesta(respuesta) {
        const colores = {
            'Contactado': 'success',
            'Interesado': 'success', 
            'No_Contactado': 'warning',
            'Contestador': 'warning',
            'Rechazo': 'error',
            'No_Interesado': 'error'
        };
        return colores[respuesta] || 'base';
    }
    
    /**
     * Formatea fecha para mostrar
     */
    formatearFecha(fecha) {
        const hoy = new Date();
        const ayer = new Date(hoy);
        ayer.setDate(ayer.getDate() - 1);
        
        if (fecha.toDateString() === hoy.toDateString()) {
            return 'Hoy';
        } else if (fecha.toDateString() === ayer.toDateString()) {
            return 'Ayer';
        } else {
            return fecha.toLocaleDateString('es-ES', { 
                weekday: 'long', 
                year: 'numeric', 
                month: 'long', 
                day: 'numeric' 
            });
        }
    }
    
    /**
     * Formatea hora para mostrar
     */
    formatearHora(fecha) {
        return fecha.toLocaleTimeString('es-ES', { 
            hour: '2-digit', 
            minute: '2-digit' 
        });
    }
    
    /**
     * Navega al registro de la gestión
     */
    navegarARegistro(event) {
        event.preventDefault();
        const gestionId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: gestionId,
                objectApiName: 'Gestion_Expedientes__c',
                actionName: 'view'
            }
        });
    }

    /**
     * Alterna el estado expandido de una gestión
     */
    toggleExpand(event) {
        const gestionId = event.currentTarget.dataset.id;
        
        // Actualizar el estado en gestionesAgrupadas
        this.gestionesAgrupadas = this.gestionesAgrupadas.map(grupo => {
            const gestionesActualizadas = grupo.gestiones.map(gestion => {
                if (gestion.id === gestionId) {
                    const expanded = !gestion.expanded;
                    return {
                        ...gestion,
                        expanded: expanded,
                        expandIcon: expanded ? 'utility:chevrondown' : 'utility:chevronright',
                        ariaHidden: expanded ? 'false' : 'true',
                        timelineItemClass: this.obtenerTimelineItemClass(gestion.medio, expanded)
                    };
                }
                return gestion;
            });
            
            return {
                ...grupo,
                gestiones: gestionesActualizadas
            };
        });
    }
    
    /**
     * Elimina una gestión
     */
    async eliminarGestion(event) {
        const gestionId = event.target.dataset.id;
        try {
            await eliminarGestionApex({ gestionId: gestionId });
            await refreshApex(this.wiredGestionesResult);
            this.mostrarToast('Eliminado', 'Gestión eliminada correctamente', 'success');
        } catch (error) {
            console.error('Error eliminando gestión:', error);
            this.mostrarToast('Error', error.body?.message || 'No se pudo eliminar la gestión', 'error');
        }
    }
    
    /**
     * Valida que los campos requeridos estén completos
     */
    validarCampos() {
        if (!this.medio) {
            this.mostrarError = true;
            this.mensajeError = 'Debe seleccionar un medio de contacto';
            return false;
        }
        
        if (!this.inicio) {
            this.mostrarError = true;
            this.mensajeError = 'Debe seleccionar el tipo de inicio';
            return false;
        }

        if (!this.operador) {
            this.mostrarError = true;
            this.mensajeError = 'Debe seleccionar un operador';
            return false;
        }
        
        if (!this.respuesta) {
            this.mostrarError = true;
            this.mensajeError = 'Debe seleccionar el tipo de respuesta';
            return false;
        }
        
        return true;
    }
    
    /**
     * Muestra un toast message
     */
    mostrarToast(titulo, mensaje, variante) {
        const evento = new ShowToastEvent({
            title: titulo,
            message: mensaje,
            variant: variante
        });
        this.dispatchEvent(evento);
    }

    limpiarFormulario() {
        this.numeroGestion = '';
        this.celular = '';
        this.medio = '';
        this.inicio = '';
        this.operador = '';
        this.respuesta = '';
        this.comentario = '';
        this.mostrarError = false;
        this.mensajeError = '';
    }
}