import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import xlsx from '@salesforce/resourceUrl/XLSX';
import puedeUsar from '@salesforce/apex/CargaMasivaCasosSE.puedeUsar';
import validar from '@salesforce/apex/CargaMasivaCasosSE.validar';
import crear from '@salesforce/apex/CargaMasivaCasosSE.crear';
import validarEdicion from '@salesforce/apex/CargaMasivaCasosSE.validarEdicion';
import editar from '@salesforce/apex/CargaMasivaCasosSE.editar';
import { reduceErrors } from 'c/utils';

const LIMITE_ARCHIVO = 10000;
const TAMANO_LOTE = 200;
const FILAS_EN_PANTALLA = 100;
const CAMPOS = {
    cuit: 'cuit',
    'razon social': 'razonSocial',
    'tipo de registro del caso': 'tipoRegistro',
    'tipo de registro': 'tipoRegistro',
    estado: 'estado',
    tipo: 'tipo',
    tema: 'tema',
    inicio: 'inicio',
    capsula: 'capsula',
    'id propietario': 'idPropietario',
    'comentario principal': 'comentarioPrincipal',
    'comentario secundario': 'comentarioSecundario',
    descripcion: 'descripcion',
    'id caso': 'idCaso',
    'caso id': 'idCaso',
    'id del caso': 'idCaso',
    id_caso: 'idCaso',
    caso_id: 'idCaso'
};
const CAMPOS_EDICION = ['estado', 'tipo', 'tema', 'inicio', 'capsula', 'idPropietario', 'comentarioPrincipal', 'comentarioSecundario', 'descripcion'];
const ENCABEZADOS_OBLIGATORIOS = ['cuit', 'tipoRegistro', 'estado', 'inicio', 'capsula', 'idPropietario'];
const ETIQUETAS = {
    cuit: 'CUIT',
    razonSocial: 'Razón Social',
    tipoRegistro: 'Tipo de registro del Caso',
    estado: 'Estado',
    inicio: 'Inicio',
    capsula: 'Cápsula',
    idPropietario: 'ID Propietario',
    idCaso: 'ID Caso',
    comentarioPrincipal: 'Comentario Principal',
    comentarioSecundario: 'Comentario Secundario'
};
const COLUMNAS_CREAR = ['CUIT', 'Tipo de registro del Caso', 'Estado', 'Tipo', 'Tema', 'Inicio', 'Cápsula', 'ID Propietario', 'Comentario Principal', 'Comentario Secundario'];
const CAMPOS_REPORTE_CREAR = ['cuit', 'tipoRegistro', 'estado', 'tipo', 'tema', 'inicio', 'capsula', 'idPropietario', 'comentarioPrincipal', 'comentarioSecundario'];
const COLUMNAS_EDITAR = ['ID Caso', 'Estado', 'Tipo', 'Tema', 'Inicio', 'Cápsula', 'ID Propietario', 'Comentario Principal', 'Comentario Secundario', 'Descripción'];
const CAMPOS_REPORTE_EDITAR = ['idCaso', 'estado', 'tipo', 'tema', 'inicio', 'capsula', 'idPropietario', 'comentarioPrincipal', 'comentarioSecundario', 'descripcion'];

export default class CargaMasivaCasosSe extends LightningElement {
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
        { label: 'CUIT', fieldName: 'cuit', type: 'text' },
        { label: 'Razón Social', fieldName: 'razonSocial', type: 'text' },
        { label: 'Cuenta', fieldName: 'cuentaNombre', type: 'text' },
        {
            label: 'Caso',
            fieldName: 'casoUrl',
            type: 'url',
            typeAttributes: { label: { fieldName: 'casoNumero' }, target: '_blank' }
        },
        { label: 'Resultado', fieldName: 'resultado', type: 'text', initialWidth: 110 },
        { label: 'Motivo', fieldName: 'motivo', type: 'text', wrapText: true }
    ];

    columnasEditar = [
        { label: 'Fila', fieldName: 'nroFila', type: 'number', initialWidth: 80 },
        { label: 'ID Caso', fieldName: 'idInformado', type: 'text' },
        {
            label: 'Caso',
            fieldName: 'casoUrl',
            type: 'url',
            typeAttributes: { label: { fieldName: 'casoNumero' }, target: '_blank' }
        },
        { label: 'Resultado', fieldName: 'resultado', type: 'text', initialWidth: 110 },
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
            ? 'Se van a actualizar los casos listos.'
            : 'Se van a crear los registros listos.';
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
            .map((fila) => ({
                ...fila,
                resultado: 'Error',
                casoUrl: fila.casoId ? '/lightning/r/Case/' + fila.casoId + '/view' : null
            }));
    }

    get hayMasErroresEnPantalla() {
        return this.resumen && this.resumen.conError > FILAS_EN_PANTALLA;
    }

    get tieneErrores() {
        return this.resumen && this.resumen.conError > 0;
    }

    handleArchivo(event) {
        const archivo = event.target.files && event.target.files[0];
        if (!archivo) {
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
            return 'La carga finalizó exitosamente. ' + verbo + ' ' + this.resumen.creados + ' casos.';
        }
        return 'La carga finalizó. Se ' + accion + ' ' + this.resumen.creados + ' de ' + this.resumen.procesados + ' casos. ' + this.resumen.conError + ' filas tuvieron error. El Excel trae esas filas, con las columnas de la plantilla y el motivo, para corregirlas y volver a cargarlas.';
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
        const encabezados = this.esEdicion ? COLUMNAS_EDITAR : COLUMNAS_CREAR;
        const ejemplo = this.esEdicion
            ? ['500000000000000AAA', 'Abierto', '', '', 'Entrante', '', '', 'FISCALIZADA', 'INFORMA VENTAS', '']
            : ['20144462980', 'Sembra Evolucion', 'Abierto', '', '', 'Saliente', 'STINE', '', '', ''];
        const libro = XLSX.utils.book_new();
        const hoja = XLSX.utils.aoa_to_sheet([encabezados, ejemplo]);
        XLSX.utils.book_append_sheet(libro, hoja, 'Casos');
        XLSX.writeFile(libro, this.esEdicion ? 'Edicion masiva casos SE.xlsx' : 'Carga masiva casos SE.xlsx');
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
        XLSX.writeFile(libro, this.esEdicion ? 'Resultados edicion masiva casos.xlsx' : 'Resultados carga masiva casos.xlsx');
    }

    valorReporte(origen, fila, campo) {
        let valor = origen[campo];
        if (valor == null || valor === '') {
            if (campo === 'idCaso') {
                valor = fila.idInformado;
            } else if (campo === 'cuit') {
                valor = fila.cuit;
            } else if (campo === 'razonSocial') {
                valor = fila.razonSocial;
            }
        }
        return valor == null ? '' : valor;
    }

    mapearFilas(crudas) {
        if (!crudas.length) {
            return [];
        }
        const presentes = new Set();
        Object.keys(crudas[0]).forEach((encabezado) => {
            const campo = CAMPOS[this.normalizar(encabezado)];
            if (campo) {
                presentes.add(campo);
            }
        });
        const obligatorios = this.esEdicion ? ['idCaso'] : ENCABEZADOS_OBLIGATORIOS;
        const faltan = obligatorios.filter((campo) => !presentes.has(campo));
        if (faltan.length) {
            throw new Error('Faltan columnas obligatorias: ' + faltan.map((campo) => ETIQUETAS[campo]).join(', ') + '.');
        }
        if (this.esEdicion && !CAMPOS_EDICION.some((campo) => presentes.has(campo))) {
            throw new Error('Incluí al menos una columna para actualizar: Estado, Tipo, Tema, Inicio, Cápsula, ID Propietario, Descripción o los comentarios.');
        }

        return crudas
            .map((cruda, indice) => {
                const fila = { nroFila: indice + 1 };
                Object.keys(cruda).forEach((encabezado) => {
                    const campo = CAMPOS[this.normalizar(encabezado)];
                    if (campo) {
                        fila[campo] = cruda[encabezado] == null ? '' : String(cruda[encabezado]).trim();
                    }
                });
                return fila;
            })
            .filter((fila) => this.esEdicion
                ? fila.idCaso || CAMPOS_EDICION.some((campo) => fila[campo])
                : ENCABEZADOS_OBLIGATORIOS.some((campo) => fila[campo]) || fila.tipo || fila.tema || fila.comentarioPrincipal || fila.comentarioSecundario);
    }

    normalizar(valor) {
        return String(valor)
            .trim()
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '');
    }

    toast(message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Carga masiva de Casos', message, variant }));
    }
}
