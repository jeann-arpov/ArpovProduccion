import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getResumen from "@salesforce/apex/CuentaGranariaToneladasController.getResumen";
import getDetalle from "@salesforce/apex/CuentaGranariaToneladasController.getDetalle";
import exportarCsv from "@salesforce/apex/CuentaGranariaToneladasController.exportarCsv";
import generarConsumoHT from "@salesforce/apex/CuentaGranariaToneladasController.generarConsumoHT";

export default class CuentaGranariaToneladas extends NavigationMixin(
  LightningElement
) {
  @api recordId;

  origenes = [];
  credito = 0;
  debito = 0;
  saldo = 0;
  movimientos = 0;
  cuentaInfo = {};
  wiredResumenResult;

  vista = "resumen";
  detalleFilas = [];
  filtroOrigen = "";
  filtroBuscar = "";
  cursorStack = [];
  cursorFecha = null;
  cursorId = null;
  nextCursorFecha = null;
  nextCursorId = null;
  hayMas = false;
  pagina = 1;

  isLoading = true;
  detalleCargando = false;
  isGenerandoConsumo = false;
  descargandoOrigen = null;
  mostrarVariedad = false;
  error;

  @wire(getResumen, { cuentaGranariaId: "$recordId" })
  wiredResumen(result) {
    this.wiredResumenResult = result;
    this.isLoading = true;
    if (result.data) {
      this.aplicarResumen(result.data);
      this.isLoading = false;
      this.error = undefined;
    } else if (result.error) {
      this.error = result.error.body
        ? result.error.body.message
        : "Error desconocido";
      this.origenes = [];
      this.isLoading = false;
    }
  }

  aplicarResumen(data) {
    this.origenes = (data.origenes || []).map((row) => ({
      ...row,
      toneladasFormatted: this.formatearConSigno(row.toneladas),
      movimientosFormatted: this.formatearEntero(row.movimientos),
      valorClass: row.esNegativo ? "cgv-neg" : "cgv-pos",
      rowClass: row.esNegativo ? "cgv-row cgv-row-neg" : "cgv-row"
    }));
    this.credito = data.credito || 0;
    this.debito = data.debito || 0;
    this.saldo = data.saldo || 0;
    this.movimientos = data.movimientos || 0;
    this.cuentaInfo = data.cuenta || {};
  }

  get listo() {
    return !this.isLoading && !this.error;
  }

  get esResumen() {
    return this.vista === "resumen";
  }

  get esDetalle() {
    return this.vista === "detalle";
  }

  get tieneOrigenes() {
    return this.origenes.length > 0;
  }

  get encabezado() {
    const cuenta = this.cuentaInfo || {};
    const partes = [];
    if (cuenta.cultivo) {
      partes.push(String(cuenta.cultivo).toUpperCase());
    }
    if (cuenta.campania) {
      partes.push(cuenta.campania);
    }
    if (cuenta.variedad) {
      partes.push(String(cuenta.variedad).toUpperCase());
    }
    if (cuenta.tecnologia) {
      partes.push(cuenta.tecnologia);
    }
    return partes.join(" · ");
  }

  get subtitulo() {
    const cuenta = this.cuentaInfo || {};
    const partes = [];
    if (cuenta.productor) {
      partes.push("Productor: " + cuenta.productor);
    }
    if (cuenta.cuit) {
      partes.push("CUIT: " + cuenta.cuit);
    }
    return partes.join(" · ");
  }

  get creditoFormatted() {
    return this.formatearConSigno(this.credito);
  }

  get debitoFormatted() {
    return this.formatearConSigno(this.debito);
  }

  get saldoFormatted() {
    return this.formatearConSigno(this.saldo);
  }

  get saldoClass() {
    return this.saldo >= 0
      ? "cgv-metric-val cgv-pos"
      : "cgv-metric-val cgv-neg";
  }

  get movimientosFormatted() {
    return this.formatearEntero(this.movimientos);
  }

  get opcionesOrigen() {
    const opciones = [{ label: "Todos los orígenes", value: "" }];
    this.origenes.forEach((row) => {
      opciones.push({ label: row.etiqueta, value: row.origen });
    });
    return opciones;
  }

  get detalleVacio() {
    return !this.detalleCargando && this.detalleFilas.length === 0;
  }

  get paginaLabel() {
    return "Página " + this.pagina;
  }

  get anteriorDisabled() {
    return this.detalleCargando || this.pagina <= 1;
  }

  get siguienteDisabled() {
    return this.detalleCargando || !this.hayMas;
  }

  get esCompraHT() {
    return this.cuentaInfo && this.cuentaInfo.esCompraHT === true;
  }

  get saldoCompraHTFormatted() {
    return this.formatearNumero(this.cuentaInfo.saldoCompraHT);
  }

  get cuentasRelacionadas() {
    if (!this.cuentaInfo || !this.cuentaInfo.cuentasRelacionadas) {
      return [];
    }
    return this.cuentaInfo.cuentasRelacionadas.map((cg) => ({
      ...cg,
      saldoFormatted: this.formatearNumero(cg.saldo),
      saldoClass: cg.saldo >= 0 ? "cgv-pos" : "cgv-neg"
    }));
  }

  get tieneCuentasRelacionadas() {
    return this.esCompraHT && this.cuentasRelacionadas.length > 0;
  }

  get puedeGenerarConsumo() {
    return this.cuentaInfo && this.cuentaInfo.puedeGenerarConsumo === true;
  }

  get generarConsumoDisabled() {
    return this.isLoading || this.isGenerandoConsumo;
  }

  formatearNumero(valor) {
    const numero = parseFloat(valor);
    if (valor === null || valor === undefined || isNaN(numero)) {
      return "0";
    }
    return numero.toLocaleString("es-AR", {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2
    });
  }

  formatearConSigno(valor) {
    const numero = parseFloat(valor);
    if (valor === null || valor === undefined || isNaN(numero)) {
      return "0";
    }
    const texto = this.formatearNumero(Math.abs(numero));
    if (numero > 0) {
      return "+" + texto;
    }
    if (numero < 0) {
      return "−" + texto;
    }
    return texto;
  }

  formatearEntero(valor) {
    const numero = parseInt(valor, 10);
    if (isNaN(numero)) {
      return "0";
    }
    return numero.toLocaleString("es-AR");
  }

  verDetalleGeneral() {
    this.abrirDetalle("");
  }

  verDetalleOrigen(event) {
    this.abrirDetalle(event.currentTarget.dataset.origen);
  }

  abrirDetalle(origen) {
    this.filtroOrigen = origen || "";
    this.filtroBuscar = "";
    this.vista = "detalle";
    this.reiniciarPagina();
    this.cargarDetalle();
  }

  volverAlResumen() {
    this.vista = "resumen";
    this.detalleFilas = [];
  }

  handleFiltroOrigen(event) {
    this.filtroOrigen = event.detail.value;
    this.reiniciarPagina();
    this.cargarDetalle();
  }

  handleFiltroBuscar(event) {
    this.filtroBuscar = event.target.value;
  }

  aplicarBusqueda() {
    this.reiniciarPagina();
    this.cargarDetalle();
  }

  handleBuscarKey(event) {
    if (event.key === "Enter") {
      this.aplicarBusqueda();
    }
  }

  reiniciarPagina() {
    this.cursorStack = [];
    this.cursorFecha = null;
    this.cursorId = null;
    this.nextCursorFecha = null;
    this.nextCursorId = null;
    this.pagina = 1;
    this.hayMas = false;
  }

  async cargarDetalle() {
    this.detalleCargando = true;
    try {
      const data = await getDetalle({
        cuentaGranariaId: this.recordId,
        origen: this.filtroOrigen || null,
        buscar: this.filtroBuscar || null,
        cursorFecha: this.cursorFecha,
        cursorId: this.cursorId
      });
      this.detalleFilas = (data.filas || []).map((tn) => ({
        ...tn,
        cantidadFormatted: this.formatearConSigno(tn.cantidad),
        cantidadClass: tn.cantidad >= 0 ? "cgv-pos" : "cgv-neg"
      }));
      this.hayMas = data.hayMas === true;
      this.mostrarVariedad = data.mostrarVariedad === true;
      this.nextCursorFecha = data.cursorFecha;
      this.nextCursorId = data.cursorId;
    } catch (error) {
      this.detalleFilas = [];
      this.mostrarError(error, "No se pudo cargar el detalle.");
    } finally {
      this.detalleCargando = false;
    }
  }

  paginaSiguiente() {
    if (!this.hayMas) {
      return;
    }
    this.cursorStack.push({ fecha: this.cursorFecha, id: this.cursorId });
    this.cursorFecha = this.nextCursorFecha;
    this.cursorId = this.nextCursorId;
    this.pagina += 1;
    this.cargarDetalle();
  }

  paginaAnterior() {
    if (this.pagina <= 1) {
      return;
    }
    const previa = this.cursorStack.pop() || { fecha: null, id: null };
    this.cursorFecha = previa.fecha;
    this.cursorId = previa.id;
    this.pagina -= 1;
    this.cargarDetalle();
  }

  async descargarCsv(event) {
    const origen = event.currentTarget.dataset.origen;
    const etiqueta = event.currentTarget.dataset.etiqueta || origen;
    this.descargandoOrigen = origen;
    try {
      const csv = await exportarCsv({
        cuentaGranariaId: this.recordId,
        origen
      });
      const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = this.nombreArchivo(etiqueta);
      link.click();
      URL.revokeObjectURL(url);
    } catch (error) {
      this.mostrarError(error, "No se pudo descargar el CSV.");
    } finally {
      this.descargandoOrigen = null;
    }
  }

  nombreArchivo(etiqueta) {
    const cuenta =
      (this.cuentaInfo && this.cuentaInfo.nombre) || "cuenta-granaria";
    const limpio = String(etiqueta || "origen").replace(/[^\w\-]+/g, "-");
    return cuenta + "-" + limpio + ".csv";
  }

  navigateToRecord(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: event.currentTarget.dataset.id,
        objectApiName: "Tonelada__c",
        actionName: "view"
      }
    });
  }

  navigateToDetalleVariedad(event) {
    event.preventDefault();
    const recordId = event.currentTarget.dataset.id;
    if (!recordId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId,
        objectApiName: "Detalle_Variedad_CG__c",
        actionName: "view"
      }
    });
  }

  navigateToCompraHT() {
    if (this.cuentaInfo && this.cuentaInfo.compraHTId) {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: this.cuentaInfo.compraHTId,
          objectApiName: "Cuenta_Granaria__c",
          actionName: "view"
        }
      });
    }
  }

  navigateToCuentaGranaria(event) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: event.currentTarget.dataset.id,
        objectApiName: "Cuenta_Granaria__c",
        actionName: "view"
      }
    });
  }

  async handleGenerarConsumo() {
    if (!this.recordId || !this.puedeGenerarConsumo) {
      return;
    }
    this.isGenerandoConsumo = true;
    try {
      const result = await generarConsumoHT({
        cuentaGranariaId: this.recordId
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Consumo generado",
          message: result?.message || "Se generó el consumo HT correctamente.",
          variant: "success"
        })
      );
      await refreshApex(this.wiredResumenResult);
    } catch (error) {
      this.mostrarError(error, "No se pudo generar el consumo.");
    } finally {
      this.isGenerandoConsumo = false;
    }
  }

  mostrarError(error, fallback) {
    const message = error?.body?.message || error?.message || fallback;
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Error",
        message,
        variant: "error"
      })
    );
  }
}
