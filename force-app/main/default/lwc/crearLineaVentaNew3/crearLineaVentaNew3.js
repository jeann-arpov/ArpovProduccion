import { api, LightningElement, track, wire } from "lwc";
import saveItem from "@salesforce/apex/CrearVentaController.saveItem";
import deleteItem from "@salesforce/apex/CrearVentaController.deleteItem";
import searchVariedades from "@salesforce/apex/CrearCompraController.searchVariedades";
import obtenerSaldoHTPorLinea from "@salesforce/apex/CrearVentaController.obtenerSaldoHTPorLinea";
import tieneHTONCPorLinea from "@salesforce/apex/CrearVentaController.tieneHTONCPorLinea";
import { LineaCompraVentaMixin } from "c/utilsHT";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import NC_PRICE_DIFFERENCE_WARNING from "@salesforce/label/c.NC_Price_Difference_Warning";
import NC_QUANTITY_DIFFERENCE_WARNING from "@salesforce/label/c.NC_Quantity_Difference_Warning";
import NC_OBSERVACIONES_REQUIRED from "@salesforce/label/c.NC_Observaciones_Required";
import NC_NO_CHANGE_WARNING from "@salesforce/label/c.NC_No_Change_Warning";
import NC_PRICE_CANNOT_HIGHER from "@salesforce/label/c.NC_Price_Cannot_Higher";
import NC_QUANTITY_CANNOT_HIGHER from "@salesforce/label/c.NC_Quantity_Cannot_Higher";
import NC_PRICE_CANNOT_NEGATIVE from "@salesforce/label/c.NC_Price_Cannot_Negative";
import NC_QUANTITY_CANNOT_NEGATIVE from "@salesforce/label/c.NC_Quantity_Cannot_Negative";

export default class CrearLineaVentaNew3 extends LineaCompraVentaMixin(
  LightningElement
) {
  @api loadingSppiner = false;
  @api preCampaign;
  @api isFuturaFlag;
  @track selectedValue;
  @track isModalOpen = false;
  @track precioLista = 0;
  @track tipoFinanciamiento;
  @track isGlobalLoading = false;
  @track loading = false;
  @track _record = {};
  @api modoNotaCreditoPrecio = false;
  @api modoNotaCreditoCantidad = false;
  @track seleccionadoParaNC = false;
  @track nuevoPrecio = 0;
  @track nuevaCantidad = 0;
  @track observacionesLocales = "";
  @track mostrarModalHT = false;
  @track saldoHTLinea = {};
  @track _tieneHT = false;
  _tieneHTInicializado = false;
  labels = {
    ncPriceDifferenceWarning: NC_PRICE_DIFFERENCE_WARNING,
    ncQuantityDifferenceWarning: NC_QUANTITY_DIFFERENCE_WARNING,
    ncObservacionesRequired: NC_OBSERVACIONES_REQUIRED,
    ncNoChangeWarning: NC_NO_CHANGE_WARNING,
    ncPriceCannotHigher: NC_PRICE_CANNOT_HIGHER,
    ncQuantityCannotHigher: NC_QUANTITY_CANNOT_HIGHER,
    ncPriceCannotNegative: NC_PRICE_CANNOT_NEGATIVE,
    ncQuantityCannotNegative: NC_QUANTITY_CANNOT_NEGATIVE
  };

  get tiposDePago() {
    return [
      { label: "Contado", value: "Contado" },
      { label: "Financiado", value: "Financiado" }
    ];
  }

  get mostrarCamposNotaCredito() {
    return this.modoNotaCreditoPrecio || this.modoNotaCreditoCantidad;
  }

  get tieneAjusteHT() {
    return this._tieneHT;
  }

  get htOriginalLinea() {
    return this.saldoHTLinea?.htOriginal ?? 0;
  }
  get htAjustadaLinea() {
    return this.saldoHTLinea?.htAjustada ?? 0;
  }
  get htRestanteLinea() {
    return this.saldoHTLinea?.htRestante ?? 0;
  }
  get etapaOriginalLinea() {
    return this.saldoHTLinea?.etapaOriginal || "";
  }
  get etapaDebitoLinea() {
    return this.saldoHTLinea?.etapaDebito || "";
  }
  get precioUnitarioLinea() {
    return this._record?.Precio_de_Lista__c;
  }
  get totalUSDLinea() {
    const precio = this._record?.Precio_de_Lista__c;
    const cantidad = this._record?.Cantidad__c;
    return precio != null && cantidad != null ? precio * cantidad : null;
  }

  async verHT() {
    try {
      this.saldoHTLinea = await obtenerSaldoHTPorLinea({
        lineaVentaId: this._record.Id
      });
      this.mostrarModalHT = true;
    } catch (error) {
      console.error("Error al obtener saldo HT:", error);
    }
  }

  cerrarModalHT() {
    this.mostrarModalHT = false;
  }

  get isFutura() {
    if (this.isFuturaFlag !== undefined) {
      return this.isFuturaFlag;
    }
    return this.preCampaign === "Futura";
  }

  get momentoEntregaCompleto() {
    return this.preCampaign != null && this.preCampaign !== "";
  }

  get tipoFinanciamientoCompleto() {
    return (
      this._record?.Tipo_de_Pago__c != null &&
      this._record?.Tipo_de_Pago__c !== ""
    );
  }

  get camposFinanciamientoCompletos() {
    if (this.isFutura) {
      return this.momentoEntregaCompleto && this.tipoFinanciamientoCompleto;
    }
    return this.momentoEntregaCompleto;
  }

  get camposFinanciamientoIncompletos() {
    return !this.camposFinanciamientoCompletos;
  }

  deleteItem(recordId) {
    return deleteItem({ itemId: this._record.Id, ventaId: recordId });
  }

  async saveItem(recordId, cultivo, productorId) {
    this.loadingSppiner = true;
    const record = await saveItem({
      ventaId: recordId,
      itemJson: JSON.stringify(this._record),
      productorId,
      cultivo
    });

    this.dispatchEvent(new CustomEvent("record", { detail: record }));
    this.loadingSppiner = false;
    this.loading = false;
    this.isGlobalLoading = true;
  }

  async searchVariedades(event) {
    const lookup = event.target;
    await searchVariedades({
      searchTerm: event.detail.searchTerm,
      selectedIds: event.detail.selectedIds,
      disponiblesIds: this.priceBookEntries.reduce(
        (ids, p) => [...ids, p.record.Product2.Variedad2__c],
        []
      )
    })
      .then((res) => lookup.setSearchResults(res))
      .catch((e) => this.onError(e));
  }

  redirectMisLicencias() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        pageName: "consulta-de-licencias-del-productor"
      }
    });
  }

  handleLoadingChange(event) {
    const { isLoading } = event.detail;
    this.isGlobalLoading = isLoading;
  }

  tipoFinanciamientoChange(event) {
    const newValue = event.target.value;
    this._record.Tipo_de_Pago__c = newValue;
    this.tipoFinanciamiento = newValue;
    this.updatePriceBasedOnTipoCompra();
    this.checkAutoSave();
    this.openModal(newValue);
  }

  openModal(value) {
    this.selectedValue = value;
    if (this.selectedValue === "Contado") {
      this.isModalOpen = true;
    }
  }

  closeModal() {
    this.isModalOpen = false;
  }

  // ===== MÉTODOS PARA NOTAS DE CRÉDITO =====

  @api
  resetearSeleccionNC() {
    this.seleccionadoParaNC = false;
    this.nuevoPrecio = this._record?.Precio_de_Lista__c || 0;
    this.nuevaCantidad = this._record?.Cantidad__c || 0;
    this.observacionesLocales = "";
  }

  handleCheckboxChange(event) {
    this.seleccionadoParaNC = event.target.checked;

    this.dispatchEvent(
      new CustomEvent("checkboxchange", {
        detail: {
          lineaId: this._record.Id,
          checked: this.seleccionadoParaNC
        }
      })
    );

    if (this.seleccionadoParaNC) {
      this.nuevoPrecio = this._record?.Precio_de_Lista__c || 0;
      this.nuevaCantidad = this._record?.Cantidad__c || 0;
      this.observacionesLocales = "";
    }
  }

  handleObservacionesChange(event) {
    this.observacionesLocales = event.target.value;

    this.dispatchEvent(
      new CustomEvent("observacioneschange", {
        detail: {
          lineaId: this._record.Id,
          observaciones: this.observacionesLocales
        }
      })
    );
  }

  handlePrecioChange(event) {
    const nuevoPrecio = parseFloat(event.target.value);
    const precioActual = this._record?.Precio_de_Lista__c || 0;

    if (nuevoPrecio > precioActual) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: this.labels.ncPriceCannotHigher,
          variant: "error"
        })
      );
      this.nuevoPrecio = precioActual;
      return;
    }

    if (nuevoPrecio < 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: this.labels.ncPriceCannotNegative,
          variant: "error"
        })
      );
      this.nuevoPrecio = 0;
      return;
    }

    this.nuevoPrecio = nuevoPrecio;

    this.dispatchEvent(
      new CustomEvent("preciochange", {
        detail: {
          lineaId: this._record.Id,
          nuevoPrecio: this.nuevoPrecio
        }
      })
    );

    const diferencia = precioActual - nuevoPrecio;
    console.log(
      `Diferencia de precio para línea ${this._record.Id}: ${diferencia}`
    );
  }

  handleCantidadChange(event) {
    const nuevaCantidad = parseInt(event.target.value);
    const cantidadActual = this._record?.Cantidad__c || 0;

    if (nuevaCantidad > cantidadActual) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: this.labels.ncQuantityCannotHigher,
          variant: "error"
        })
      );
      this.nuevaCantidad = cantidadActual;
      return;
    }

    if (nuevaCantidad < 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: this.labels.ncQuantityCannotNegative,
          variant: "error"
        })
      );
      this.nuevaCantidad = 0;
      return;
    }

    this.nuevaCantidad = nuevaCantidad;

    this.dispatchEvent(
      new CustomEvent("cantidadchange", {
        detail: {
          lineaId: this._record.Id,
          nuevaCantidad: this.nuevaCantidad
        }
      })
    );

    const diferencia = cantidadActual - nuevaCantidad;
    console.log(
      `Diferencia de cantidad para línea ${this._record.Id}: ${diferencia}`
    );
  }

  @api
  obtenerDatosAjusteNC() {
    if (!this.seleccionadoParaNC || !this._record?.Id) {
      return null;
    }

    const valorAnterior = this.modoNotaCreditoPrecio
      ? this._record.Precio_de_Lista__c
      : this._record.Cantidad__c;
    const valorNuevo = this.modoNotaCreditoPrecio
      ? this.nuevoPrecio
      : this.nuevaCantidad;

    if (
      !this.observacionesLocales ||
      this.observacionesLocales.trim().length < 20
    ) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Debe ingresar al menos 20 caracteres de observaciones.",
          variant: "error"
        })
      );
      return null;
    }

    return {
      lineaId: this._record.Id,
      tipoAjuste: this.modoNotaCreditoPrecio ? "precio" : "cantidad",
      valorAnterior: valorAnterior,
      valorNuevo: valorNuevo,
      observaciones: this.observacionesLocales
    };
  }

  calcularDiferencia() {
    if (this.modoNotaCreditoPrecio) {
      const precioActual = this._record?.Precio_de_Lista__c || 0;
      return precioActual - this.nuevoPrecio;
    } else if (this.modoNotaCreditoCantidad) {
      const cantidadActual = this._record?.Cantidad__c || 0;
      return cantidadActual - this.nuevaCantidad;
    }
    return 0;
  }

  get mostrarDiferencia() {
    const diferencia = this.calcularDiferencia();
    if (this.modoNotaCreditoPrecio) {
      return `Diferencia de precio: ${diferencia}`;
    } else if (this.modoNotaCreditoCantidad) {
      return `Diferencia de cantidad: ${diferencia}`;
    }
    return "";
  }

  renderedCallback() {
    super.renderedCallback();
    if (this._record?.Id && !this._tieneHTInicializado) {
      this._tieneHTInicializado = true;
      this.verificarHT();
    }
  }

  async verificarHT() {
    try {
      if (this._record?.Id) {
        this._tieneHT = await tieneHTONCPorLinea({
          lineaVentaId: this._record.Id
        });
      }
    } catch (error) {
      console.error("Error al verificar HT:", error);
    }
  }
}
