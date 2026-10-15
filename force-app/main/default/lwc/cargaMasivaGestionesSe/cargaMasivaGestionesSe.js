import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import xlsx from '@salesforce/resourceUrl/XLSX';
import puedeUsar from '@salesforce/apex/CargaMasivaGestionesSE.puedeUsar';
import validar from '@salesforce/apex/CargaMasivaGestionesSE.validar';
import crear from '@salesforce/apex/CargaMasivaGestionesSE.crear';
import validarEdicion from '@salesforce/apex/CargaMasivaGestionesSE.validarEdicion';
import editar from '@salesforce/apex/CargaMasivaGestionesSE.editar';
import { reduceErrors } from 'c/utils';

const LIMITE_ARCHIVO = 10000;
const TAMANO_LOTE = 100;
const FILAS_EN_PANTALLA = 100;
const CAMPOS = {
    caso_id: 'casoId',
    'caso id': 'casoId',
    casoid: 'casoId',
    'id caso': 'casoId',
    'id del caso': 'casoId',
    medio: 'medio',
    'tipo de gestion': 'tipoGestion',
    'tipo gestion': 'tipoGestion',
    respuesta: 'respuesta',
    efectividad: 'efectividad',
    celular: 'celular',
    'numero de celular': 'celular',
    telefono: 'celular',
    comentario: 'comentario',
    'id propietario': 'idPropietario'
};
const ENCABEZADOS_OBLIGATORIOS = ['casoId', 'medio', 'tipoGestion', 'idPropietario'];
const CAMPOS_EDICION = {
    'id gestion': 'idGestion',
    'gestion id': 'idGestion',
    'id de gestion': 'idGestion',
    'id de la gestion': 'idGestion',
    'numero de gestion': 'idGestion',
    'nro de gestion': 'idGestion',
    'nro gestion': 'idGestion',
    'numero gestion': 'idGestion',
    medio: 'medio',
    'tipo de gestion': 'tipoGestion',
    'tipo gestion': 'tipoGestion',
    respuesta: 'respuesta',
    efectividad: 'efectividad',
    celular: 'celular',
    'numero de celular': 'celular',
    telefono: 'celular',
    comentario: 'comentario',
    'id propietario': 'idPropietario'
};
const CAMPOS_ACTUALIZABLES = ['medio', 'tipoGestion', 'respuesta', 'efectividad', 'celular', 'comentario', 'idPropietario'];
const ETIQUETAS = {
    casoId: 'Caso_ID',
    medio: 'Medio',
    tipoGestion: 'Tipo de Gestión',
    respuesta: 'Respuesta',
    efectividad: 'Efectividad',
    idGestion: 'ID Gestión',
    idPropietario: 'ID Propietario'
};
const COLUMNAS_CREAR = ['Caso_ID', 'Medio', 'Tipo de Gestión', 'ID Propietario', 'Respuesta', 'Efectividad', 'Celular', 'Comentario'];
const CAMPOS_REPORTE_CREAR = ['casoId', 'medio', 'tipoGestion', 'idPropietario', 'respuesta', 'efectividad', 'celular', 'comentario'];
const COLUMNAS_EDITAR = ['ID Gestión', 'Medio', 'Tipo de Gestión', 'ID Propietario', 'Respuesta', 'Efectividad', 'Celular', 'Comentario'];
const CAMPOS_REPORTE_EDITAR = ['idGestion', 'medio', 'tipoGestion', 'idPropietario', 'respuesta', 'efectividad', 'celular', 'comentario'];

export default class CargaMasivaGestionesSe extends LightningElement {
    modo = 'crear';
    step = '1';
    loading = false;
    xlsxListo = false;
    filas = [];
    resumen = null;
    archivoNombre = '';
    progreso = '';
    avance = 0;
    totalAvance = 0;

    columnasCrear = [
        { label: 'Fila', fieldName: 'nroFila', type: 'number', initialWidth: 80 },
        { label: 'Caso_ID', fieldName: 'casoIdTexto', type: 'text' },
        { label: 'Medio', fieldName: 'medio', type: 'text' },
        { label: 'Tipo de Gestión', fieldName: 'tipoGestion', type: 'text' },
        {
            label: 'Caso',
            fieldName: 'casoUrl',
            type: 'url',
            typeAttributes: { label: { fieldName: 'casoNumero' }, target: '_blank' }
        },
        { label: 'Resultado', fieldName: 'resultado', type: 'text', initialWidth: 120 },
        { label: 'Motivo', fieldName: 'motivo', type: 'text', wrapText: true }
    ];

    columnasEditar = [
        { label: 'Fila', fieldName: 'nroFila', type: 'number', initialWidth: 80 },
        { label: 'ID Gestión', fieldName: 'idInformado', type: 'text' },
        { label: 'Medio', fieldName: 'medio', type: 'text' },
        { label: 'Tipo de Gestión', fieldName: 'tipoGestion', type: 'text' },
        { label: 'Gestión', fieldName: 'gestionNombre', type: 'text' },
        { label: 'Resultado', fieldName: 'resultado', type: 'text', initialWidth: 120 },
        { label: 'Motivo', fieldName: 'motivo', type: 'text', wrapText: true }
    ];

    @wire(puedeUsar)
    acceso;

    connectedCallback() {
        loadScript(this, xlsx)
            .then(() => {
                this.xlsxListo = true;
            })
            .catch(() => {
                this.toast('No se pudo cargar el lector de Excel', 'error');
            });
    }

    get mensajeAcceso() {
        return this.acceso.error ? reduceErrors(this.acceso.error).join(' ') : '';
    }

    get sinAcceso() {
        return this.acceso.data === false;
    }

    get conAcceso() {
        return this.acceso.data === true;
    }

    get esEdicion() {
        return this.modo === 'editar';
    }

    get varianteCrear() {
        return this.esEdicion ? 'neutral' : 'brand';
    }

    get varianteEditar() {
        return this.esEdicion ? 'brand' : 'neutral';
    }

    get columnas() {
        return this.esEdicion ? this.columnasEditar : this.columnasCrear;
    }

    get etiquetaConfirmar() {
        return this.esEdicion ? 'Confirmar edición' : 'Confirmar creación';
    }

    get etiquetaListos() {
        return this.esEdicion ? 'Listos para actualizar' : 'Listos para crear';
    }

    get etiquetaResultado() {
        return this.esEdicion ? 'Actualizados' : 'Creados';
    }

    get textoConfirmacion() {
        return this.esEdicion
            ? 'Se van a actualizar las gestiones listas.'
            : 'Se van a crear las gestiones listas.';
    }

    get pasos() {
        const actual = Number(this.step);
        return ['Archivo', 'Validación', 'Resultado'].map((label, index) => {
            const numero = index + 1;
            let estado = 'pendiente';
            if (numero < actual) {
                estado = 'listo';
            } else if (numero === actual) {
                estado = 'actual';
            }
            return {
                value: String(numero),
                numero: String(numero),
                label,
                clase: `paso ${estado}`
            };
        });
    }

    get enCarga() {
        return this.step === '1';
    }

    get enConfirmacion() {
        return this.step === '2';
    }

    get enResultado() {
        return this.step === '3';
    }

    get confirmarDeshabilitado() {
        return !(this.resumen && this.resumen.validos > 0) || this.loading;
    }

    get porcentaje() {
        if (!this.totalAvance) {
            return 0;
        }
        return Math.min(100, Math.round((this.avance / this.totalAvance) * 100));
    }

    get filasVista() {
        if (!this.resumen) {
            return [];
        }
        return this.resumen.filas
            .filter((fila) => !fila.valido)
            .slice(0, FILAS_EN_PANTALLA)
            .map((fila) => this.filaVista(fila));
    }

    get hayMasErroresEnPantalla() {
        return this.resumen && this.resumen.conError > FILAS_EN_PANTALLA;
    }

    get tieneErrores() {
        return this.resumen && this.resumen.conError > 0;
    }

    get mostrarFinalizado() {
        return this.step === '3' && this.resumen;
    }

    get mensajeFinalizado() {
        if (!this.resumen) {
            return '';
        }
        const accion = this.esEdicion ? 'actualizaron' : 'crearon';
        const verbo = this.esEdicion ? 'Se actualizaron' : 'Se crearon';
        if (!this.resumen.conError) {
            return 'La carga finalizó exitosamente. ' + verbo + ' ' + this.resumen.creados + ' gestiones.';
        }
        return 'La carga finalizó. Se ' + accion + ' ' + this.resumen.creados + ' de ' + this.resumen.procesados + ' gestiones. ' + this.resumen.conError + ' filas tuvieron error. El Excel trae esas filas, con las columnas de la plantilla y el motivo, para corregirlas y volver a cargarlas.';
    }

    handleArchivo(event) {
        const archivo = event.target.files && event.target.files[0];
        if (!archivo) {
            return;
        }
        const nombre = (archivo.name || '').toLowerCase();
        if (!nombre.endsWith('.xlsx') && !nombre.endsWith('.xls') && !nombre.endsWith('.csv')) {
            this.toast('El archivo tiene que ser un Excel (.xlsx)', 'error');
            return;
        }
        if (!this.xlsxListo) {
            this.toast('El lector de Excel todavía se está cargando', 'warning');
            return;
        }
        this.archivoNombre = archivo.name;
        this.loading = true;
        const lector = new FileReader();
        lector.onload = () => {
            try {
                const libro = XLSX.read(lector.result, { type: 'array' });
                const hoja = libro.Sheets[libro.SheetNames[0]];
                const crudas = XLSX.utils.sheet_to_json(hoja, { defval: '', raw: false });
                this.filas = this.mapearFilas(crudas);
                if (!this.filas.length) {
                    this.loading = false;
                    this.toast('El archivo no tiene filas para procesar', 'error');
                    return;
                }
                if (this.filas.length > LIMITE_ARCHIVO) {
                    this.loading = false;
                    this.filas = [];
                    this.toast('El archivo supera el máximo de ' + LIMITE_ARCHIVO + ' filas', 'error');
                    return;
                }
                this.pedirValidacion();
            } catch (e) {
                this.loading = false;
                this.toast(e && e.message ? e.message : reduceErrors(e).join('\n'), 'error');
            }
        };
        lector.readAsArrayBuffer(archivo);
    }

    async pedirValidacion() {
        this.loading = true;
        const resumen = this.resumenVacio();
        try {
            const metodo = this.esEdicion ? validarEdicion : validar;
            await this.recorrerLotes(this.filas, 'Validando', async (lote) => {
                this.sumar(resumen, await metodo({ filas: lote }));
            });
            this.resumen = resumen;
            this.step = '2';
        } catch (error) {
            this.toast(reduceErrors(error).join('\n'), 'error');
        } finally {
            this.limpiarProgreso();
        }
    }

    async confirmar() {
        this.loading = true;
        const porFila = new Map(this.resumen.filas.map((fila) => [fila.nroFila, { ...fila }]));
        const validas = this.filas.filter((fila) => porFila.get(fila.nroFila) && porFila.get(fila.nroFila).valido);
        let creados = 0;
        try {
            const metodo = this.esEdicion ? editar : crear;
            await this.recorrerLotes(validas, this.esEdicion ? 'Actualizando' : 'Creando', async (lote) => {
                const parcial = await metodo({ filas: lote });
                parcial.filas.forEach((fila) => porFila.set(fila.nroFila, fila));
                creados += parcial.creados || 0;
            });
            this.publicarResultado(porFila, creados);
        } catch (error) {
            this.toast(reduceErrors(error).join('\n'), 'error');
            if (creados > 0) {
                this.publicarResultado(porFila, creados);
            }
        } finally {
            this.limpiarProgreso();
        }
    }

    async recorrerLotes(filas, etiqueta, procesar) {
        const lotes = this.partir(filas);
        this.avance = 0;
        this.totalAvance = filas.length;
        this.progreso = etiqueta + ' 0 de ' + filas.length;
        for (let i = 0; i < lotes.length; i++) {
            await procesar(lotes[i]);
            this.avance = Math.min(filas.length, (i + 1) * TAMANO_LOTE);
            this.progreso = etiqueta + ' ' + this.avance + ' de ' + filas.length;
        }
    }

    publicarResultado(porFila, creados) {
        const filas = Array.from(porFila.values()).sort((a, b) => a.nroFila - b.nroFila);
        const conError = filas.filter((fila) => !fila.valido).length;
        this.resumen = {
            procesados: filas.length,
            validos: filas.length - conError,
            conError,
            creados,
            filas
        };
        this.step = '3';
        if (conError > 0) {
            this.descargarErrores();
        }
    }

    aceptarFinalizado() {
        this.volver();
    }

    resumenVacio() {
        return { procesados: 0, validos: 0, conError: 0, creados: 0, filas: [] };
    }

    sumar(resumen, parcial) {
        resumen.procesados += parcial.procesados || 0;
        resumen.validos += parcial.validos || 0;
        resumen.conError += parcial.conError || 0;
        resumen.creados += parcial.creados || 0;
        resumen.filas = resumen.filas.concat(parcial.filas || []);
    }

    partir(filas) {
        const lotes = [];
        for (let i = 0; i < filas.length; i += TAMANO_LOTE) {
            lotes.push(filas.slice(i, i + TAMANO_LOTE));
        }
        return lotes;
    }

    limpiarProgreso() {
        this.loading = false;
        this.progreso = '';
        this.avance = 0;
        this.totalAvance = 0;
    }

    elegirCrear() {
        this.modo = 'crear';
        this.volver();
    }

    elegirEditar() {
        this.modo = 'editar';
        this.volver();
    }

    volver() {
        this.step = '1';
        this.filas = [];
        this.resumen = null;
        this.archivoNombre = '';
        this.limpiarProgreso();
    }

    descargarPlantilla() {
        if (!this.xlsxListo) {
            this.toast('El lector de Excel todavía se está cargando', 'warning');
            return;
        }
        const libro = XLSX.utils.book_new();
        const hoja = XLSX.utils.aoa_to_sheet(this.esEdicion
            ? [COLUMNAS_EDITAR, ['GE-00001', 'Email', '', '', 'Sin contacto', '', '', '']]
            : [COLUMNAS_CREAR, ['500000000000000AAA', 'WhatsApp', 'Saliente', '005000000000000AAA', '', '', '', '']]);
        XLSX.utils.book_append_sheet(libro, hoja, 'Gestiones');
        XLSX.writeFile(libro, this.esEdicion ? 'Edicion masiva gestiones SE.xlsx' : 'Carga masiva gestiones SE.xlsx');
    }

    descargarErrores() {
        if (!this.resumen || !this.xlsxListo) {
            return;
        }
        const columnas = this.esEdicion ? COLUMNAS_EDITAR : COLUMNAS_CREAR;
        const campos = this.esEdicion ? CAMPOS_REPORTE_EDITAR : CAMPOS_REPORTE_CREAR;
        const originales = new Map(this.filas.map((fila) => [fila.nroFila, fila]));
        const errores = this.resumen.filas
            .filter((fila) => !fila.valido)
            .map((fila) => {
                const origen = originales.get(fila.nroFila) || {};
                const salida = {};
                columnas.forEach((columna, indice) => {
                    salida[columna] = this.valorReporte(origen, fila, campos[indice]);
                });
                salida.Error = fila.motivo || '';
                return salida;
            });
        if (!errores.length) {
            return;
        }
        const libro = XLSX.utils.book_new();
        const hoja = XLSX.utils.json_to_sheet(errores, { header: columnas.concat('Error') });
        XLSX.utils.book_append_sheet(libro, hoja, 'Errores');
        XLSX.writeFile(libro, this.esEdicion ? 'Resultados edicion masiva gestiones.xlsx' : 'Resultados carga masiva gestiones.xlsx');
    }

    valorReporte(origen, fila, campo) {
        let valor = origen[campo];
        if (valor == null || valor === '') {
            if (campo === 'idGestion') {
                valor = fila.idInformado || fila.gestionNombre;
            } else if (campo === 'casoId') {
                valor = fila.casoIdTexto;
            } else if (campo === 'medio') {
                valor = fila.medio;
            } else if (campo === 'tipoGestion') {
                valor = fila.tipoGestion;
            } else if (campo === 'respuesta') {
                valor = fila.respuesta;
            } else if (campo === 'efectividad') {
                valor = fila.efectividad;
            } else if (campo === 'celular') {
                valor = fila.celular;
            } else if (campo === 'comentario') {
                valor = fila.comentario;
            }
        }
        return valor == null ? '' : valor;
    }

    descargarResultado() {
        if (!this.resumen || !this.xlsxListo) {
            return;
        }
        const filas = this.resumen.filas.map((fila) => ({
            Fila: fila.nroFila,
            'ID Gestión': fila.idInformado || fila.gestionNombre || '',
            Caso_ID: fila.casoIdTexto,
            Medio: fila.medio,
            'Tipo de Gestión': fila.tipoGestion,
            Caso: fila.casoNumero || '',
            Resultado: fila.valido ? 'Procesada correctamente' : 'Rechazada',
            'Motivo del rechazo': fila.motivo || '',
            Gestión: fila.gestionNombre || ''
        }));
        const libro = XLSX.utils.book_new();
        const hoja = XLSX.utils.json_to_sheet(filas);
        XLSX.utils.book_append_sheet(libro, hoja, 'Resultado');
        XLSX.writeFile(libro, 'Resultado carga masiva gestiones.xlsx');
    }

    filaVista(fila) {
        return {
            ...fila,
            resultado: 'Error',
            casoUrl: fila.casoId ? '/lightning/r/Case/' + fila.casoId + '/view' : null
        };
    }

    mapearFilas(crudas) {
        if (!crudas.length) {
            return [];
        }
        const mapa = this.esEdicion ? CAMPOS_EDICION : CAMPOS;
        const obligatorios = this.esEdicion ? ['idGestion'] : ENCABEZADOS_OBLIGATORIOS;
        const presentes = new Set();
        Object.keys(crudas[0]).forEach((encabezado) => {
            const campo = mapa[this.normalizar(encabezado)];
            if (campo) {
                presentes.add(campo);
            }
        });
        const faltan = obligatorios.filter((campo) => !presentes.has(campo));
        if (faltan.length) {
            throw new Error('Faltan columnas obligatorias: ' + faltan.map((campo) => ETIQUETAS[campo]).join(', ') + '.');
        }
        if (this.esEdicion && !CAMPOS_ACTUALIZABLES.some((campo) => presentes.has(campo))) {
            throw new Error('Incluí al menos una columna para actualizar: Medio, Tipo de Gestión, ID Propietario, Respuesta, Efectividad, Celular o Comentario.');
        }

        return crudas
            .map((cruda, indice) => {
                const fila = { nroFila: indice + 1 };
                Object.keys(cruda).forEach((encabezado) => {
                    const campo = mapa[this.normalizar(encabezado)];
                    if (campo) {
                        fila[campo] = cruda[encabezado] == null ? '' : String(cruda[encabezado]).trim();
                    }
                });
                return fila;
            })
            .filter((fila) => this.esEdicion
                ? fila.idGestion || CAMPOS_ACTUALIZABLES.some((campo) => fila[campo])
                : ENCABEZADOS_OBLIGATORIOS.some((campo) => fila[campo]) || fila.celular || fila.comentario);
    }

    normalizar(valor) {
        return String(valor)
            .trim()
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/_+/g, ' ')
            .replace(/\s+/g, ' ');
    }

    toast(message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Carga masiva de Gestiones', message, variant }));
    }
}
