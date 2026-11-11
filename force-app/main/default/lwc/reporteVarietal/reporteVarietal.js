import { LightningElement, api } from 'lwc';
import getOpciones from '@salesforce/apex/ReporteVarietalController.getOpciones';
import getReporte from '@salesforce/apex/ReporteVarietalController.getReporte';

const ESTADOS = [
    { label: 'Todos los estados', value: '' },
    { label: 'En regla', value: 'En regla' },
    { label: 'Debe regularizar', value: 'Debe regularizar' },
    { label: 'Sin entregas', value: 'Sin entregas' }
];

export default class ReporteVarietal extends LightningElement {
    @api recordId;

    abierto = false;
    cargando = false;
    error;
    opcionesListas = false;
    campanas = [];
    semilleros = [];
    campaniaId = '';
    semillero = '';
    estado = '';
    reporte;

    get estados() {
        return ESTADOS;
    }

    get campanaOpciones() {
        return this.campanas.map((item) => ({ ...item, selected: item.value === this.campaniaId }));
    }

    get semilleroOpciones() {
        return [{ label: 'Todos los semilleros', value: '' }, ...this.semilleros];
    }

    get tituloDesglose() {
        const campana = this.campanas.find((item) => item.value === this.campaniaId);
        return campana ? `Desglose por variedad · Trigo ${campana.label}` : 'Desglose por variedad';
    }

    get creditoFormatted() {
        return this.formatear(this.reporte?.credito);
    }

    get debitoFormatted() {
        return this.formatear(this.reporte?.debito);
    }

    get saldoFormatted() {
        return this.formatear(this.reporte?.saldo);
    }

    get saldoClass() {
        return `rv-metric-val ${this.claseValor(this.reporte?.saldo)}`;
    }

    get expedientesFormatted() {
        return new Intl.NumberFormat('es-AR').format(this.reporte?.expedientesAbiertos || 0);
    }

    get filas() {
        return (this.reporte?.filas || []).map((fila) => ({
            ...fila,
            rowClass: fila.estado === 'Debe regularizar' ? 'rv-row-neg' : '',
            estadoClass: fila.estado === 'Debe regularizar'
                ? 'rv-chip is-warn'
                : fila.estado === 'Sin entregas'
                    ? 'rv-chip is-muted'
                    : 'rv-chip is-ok',
            compraSfFormatted: this.formatear(fila.compraSf),
            compraSfDebitoFormatted: this.formatear(fila.compraSfDebito),
            compraHtFormatted: this.formatear(fila.compraHt),
            cesionFormatted: this.formatear(fila.cesion),
            entregasFormatted: this.formatear(fila.entregas),
            otrosFormatted: this.formatear(fila.otros),
            saldoFormatted: this.formatear(fila.saldo),
            saldoClass: this.claseValor(fila.saldo)
        }));
    }

    get tieneFilas() {
        return this.filas.length > 0;
    }

    get muestraOtros() {
        return (this.reporte?.filas || []).some((fila) => Number(fila.otros || 0) !== 0);
    }

    get muestraCompraSfDebito() {
        return (this.reporte?.filas || []).some((fila) => Number(fila.compraSfDebito || 0) !== 0);
    }

    async abrir() {
        this.abierto = true;
        this.error = undefined;
        if (!this.opcionesListas) {
            await this.cargarOpciones();
        }
        await this.cargar();
    }

    cerrar() {
        this.abierto = false;
    }

    async cambiarCampania(event) {
        this.campaniaId = event.target.value;
        await this.cargar();
    }

    async cambiarSemillero(event) {
        this.semillero = event.target.value;
        await this.cargar();
    }

    async cambiarEstado(event) {
        this.estado = event.target.value;
        await this.cargar();
    }

    async cargarOpciones() {
        this.cargando = true;
        try {
            const opciones = await getOpciones({ productorId: this.recordId });
            this.campanas = (opciones.campanas || []).map((item) => ({ label: item.nombre, value: item.id }));
            this.semilleros = (opciones.semilleros || []).map((item) => ({ label: item.nombre, value: item.id }));
            this.campaniaId = opciones.campaniaActual || (this.campanas.length ? this.campanas[0].value : '');
            this.opcionesListas = true;
        } catch (error) {
            this.error = this.mensaje(error);
        } finally {
            this.cargando = false;
        }
    }

    async cargar() {
        if (!this.opcionesListas) {
            return;
        }
        this.cargando = true;
        this.error = undefined;
        try {
            this.reporte = await getReporte({
                productorId: this.recordId,
                campaniaId: this.campaniaId || null,
                semillero: this.semillero || null,
                estado: this.estado || null
            });
        } catch (error) {
            this.reporte = undefined;
            this.error = this.mensaje(error);
        } finally {
            this.cargando = false;
        }
    }

    formatear(valor) {
        const numero = Number(valor || 0);
        const texto = new Intl.NumberFormat('es-AR', { maximumFractionDigits: 0 }).format(Math.abs(numero));
        if (numero > 0) {
            return `+${texto}`;
        }
        if (numero < 0) {
            return `−${texto}`;
        }
        return texto;
    }

    claseValor(valor) {
        const numero = Number(valor || 0);
        if (numero > 0) {
            return 'rv-pos';
        }
        if (numero < 0) {
            return 'rv-neg';
        }
        return '';
    }

    mensaje(error) {
        return error?.body?.message || 'No se pudo cargar el reporte varietal.';
    }
}
