import { LightningElement, api, track } from "lwc";
import { CompraVentaMixin } from "c/utilsHT";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {
  isHtFuturaPromoScreen,
  qualifiesForHtFuturaPromoAggregate,
  resolveBaseListPrice,
  resolveHtFuturaPromoUiState,
  scheduleHtFuturaPromoEval,
  cancelHtFuturaPromoEval,
  sumHtFuturaPromoEligibleQuantity,
  MSG_PROMO_ACTIVA
} from "c/htCondicionPromocionalGdm";

import searchProductores from "@salesforce/apex/CrearVentaController.searchProductores";
import getData from "@salesforce/apex/CrearVentaController.getData";
import updateOpportunity from "@salesforce/apex/CrearVentaController.updateOpportunity";
import finalizarVenta from "@salesforce/apex/CrearVentaController.finalizarVenta";
import anular from "@salesforce/apex/CrearVentaController.anular";
import getSemilleroData from "@salesforce/apex/CrearVentaController.getSemilleroData";
import canFinish from "@salesforce/apex/CrearVentaController.canFinish";
import getProductsData from "@salesforce/apex/CrearVentaController.getProductsData";
import getObservaciones from "@salesforce/apex/CrearVentaController.getObservaciones";
import saveObvservations from "@salesforce/apex/CrearVentaController.saveObvservations";
import getAccountFromUserByVenta from "@salesforce/apex/UtilsVentaHt.getAccountFromUserByVenta";
import updateTipoPago from "@salesforce/apex/CrearVentaController.updateTipoPago";
import verificarExpedienteEnHTDisponible from "@salesforce/apex/ExpedientesController.verificarExpedienteEnHTDisponible";
import procesarNotaCreditoParcialPrecio from "@salesforce/apex/CrearVentaController.crearNotaCreditoParcialPrecio";
import procesarNotaCreditoParcialCantidad from "@salesforce/apex/CrearVentaController.crearNotaCreditoParcialCantidad";
import verificarNotasCreditoPendientes from "@salesforce/apex/CrearVentaController.verificarNotasCreditoPendientes";

import { NavigationMixin } from "lightning/navigation";
import basePath from "@salesforce/community/basePath";
import icons from "c/icons";
import resourcePortal from "@salesforce/resourceUrl/resourcePortal";
import NC_ALERT_TITLE from "@salesforce/label/c.NC_Alert_Title";
import NC_ALERT_MESSAGE from "@salesforce/label/c.NC_Alert_Message";
import NC_CLOSE_ALERT from "@salesforce/label/c.NC_Close_Alert";
import NC_VIEW_LABEL from "@salesforce/label/c.NC_View_Label";
import NC_NO_LINES_SELECTED from "@salesforce/label/c.NC_No_Lines_Selected";
import NC_ALL_OBSERVACIONES_REQUIRED from "@salesforce/label/c.NC_All_Observaciones_Required";
import NC_PROCESS_SUCCESS from "@salesforce/label/c.NC_Process_Success";
import NC_MODE_CANCELED from "@salesforce/label/c.NC_Mode_Canceled";
import NC_PROCESS_PRICE from "@salesforce/label/c.NC_Process_Price";
import NC_PROCESS_QUANTITY from "@salesforce/label/c.NC_Process_Quantity";
import NC_PROCESS_GENERIC from "@salesforce/label/c.NC_Process_Generic";
import NC_BUTTON_PRICE from "@salesforce/label/c.NC_Button_Price";
import NC_BUTTON_QUANTITY from "@salesforce/label/c.NC_Button_Quantity";
import NC_BUTTON_CANCEL from "@salesforce/label/c.NC_Button_Cancel";
import NC_TOTAL_BUTTON from "@salesforce/label/c.NC_Total_Button";
import NC_CONFIRM_MODAL_TITLE from "@salesforce/label/c.NC_Confirm_Modal_Title";
import NC_CONFIRM_MODAL_MESSAGE from "@salesforce/label/c.NC_Confirm_Modal_Message";
import NC_CONFIRM_MODAL_CONFIRM from "@salesforce/label/c.NC_Confirm_Modal_Confirm";

/** Temporal: true = no se muestra el modal de expediente negativo en HT disponible ni se detiene finalizar. */
const OMITIR_MODAL_ALERTA_EXPEDIENTE_NEGATIVO = true;

/** Promo HT Futura Trigo GDM (USD 9 con â‰¥200 HT). ValidaciÃ³n en TEST; prod pendiente. */
const PROMO_HT_FUTURA_HABILITADA = true;

export default class CrearVenta2 extends CompraVentaMixin(LightningElement) {
  iconCebadaUrl = `${resourcePortal}/resourcePortal/images/prd-cebada.svg`;
  iconSojaHTUrl = `${resourcePortal}/resourcePortal/images/prd-soja.svg`;
  iconTrigoHTUrl = `${resourcePortal}/resourcePortal/images/prd-trigo.svg`;
  iconVenderHTUrl = `${resourcePortal}/resourcePortal/images/icon-vender-ht.svg`;
  iconCondicionesHTUrl = `${resourcePortal}/resourcePortal/images/icon-condiciones.svg`;

  productor;
  cultivoSeleccionadoId;
  semilleroIcono = false;

  @track showResumen = false;
  @api recordId;

  @track showFileUploadModal = false;
  @track showObsModal = false;
  @track mostrarBoton = false; // habilita botones por cuenta (Apex)
  @track uploadFactura = true;
  @track observaciones;
  @track DataCompra;
  @track isOpen = false;
  @track isOpen2 = false;
  @track haveLicence;
  @track haveOrigenLegal;
  @track Blanqueo;
  @track Futura;
  tipoCompraSeleccionado = null; // 'Futura' | 'Disponible'
  @track _lineasListasFlag = false;
  @track guardandoLineas = false;
  @track finalizandoOperacion = false;

  formattedDate = null;
  customCode = null;

  subscription = null;
  @track isLoading = false;
  @track modoNotaCreditoPrecio = false;
  @track modoNotaCreditoCantidad = false;
  @track lineasSeleccionadasNC = [];
  @track botonProcesarNCVisible = false;
  @track observacionesLineasNC = {};
  @track infoNotasCredito = {};
  @track mostrarAlertaNotaCredito = false;
  @track notasCreditoPendientes = [];
  @track todasLasNC = [];
  @track showConfirmNCTotalModal = false;
  labels = {
    ncAlertTitle: NC_ALERT_TITLE,
    ncAlertMessage: NC_ALERT_MESSAGE,
    ncCloseAlert: NC_CLOSE_ALERT,
    ncViewLabel: NC_VIEW_LABEL,
    ncNoLinesSelected: NC_NO_LINES_SELECTED,
    ncAllObservacionesRequired: NC_ALL_OBSERVACIONES_REQUIRED,
    ncProcessSuccess: NC_PROCESS_SUCCESS,
    ncModeCanceled: NC_MODE_CANCELED,
    ncProcessPrice: NC_PROCESS_PRICE,
    ncProcessQuantity: NC_PROCESS_QUANTITY,
    ncProcessGeneric: NC_PROCESS_GENERIC,
    ncButtonPrice: NC_BUTTON_PRICE,
    ncButtonQuantity: NC_BUTTON_QUANTITY,
    ncButtonCancel: NC_BUTTON_CANCEL,
    ncTotalButton: NC_TOTAL_BUTTON,
    ncConfirmModalTitle: NC_CONFIRM_MODAL_TITLE,
    ncConfirmModalMessage: NC_CONFIRM_MODAL_MESSAGE,
    ncConfirmModalConfirm: NC_CONFIRM_MODAL_CONFIRM
  };

  tipoPago = null; // 'Contado' | 'Financiado'
  pendingFinalizar = false; // para reintentar
  pendingFinalizarPorExpediente = false;
  shouldMarkRevisarCompra = false;

  htFuturaPromoMessage = null;
  htFuturaPromoVariant = "success";
  htFuturaPromoPreviouslyQualified = false;
  htFuturaPromoCelebrationShown = false;

  icons = icons.compraVenta;

  get currentVentaId() {
    if (this.recordId) {
      return this.recordId;
    }
    if (
      window.location.href.includes("venta-ht/") &&
      !window.location.href.includes("venta-ht/Venta_HT__c/")
    ) {
      return window.location.href.split("venta-ht/")[1].split("/")[0];
    }
    return new URL(window.location.href).searchParams.get("recordId");
  }

  get mostrarFacturaYObs() {
    const estado = this.data?.record?.Estado__c;
    if (estado === "Pagada" || estado === "Facturada" || this.esNotaCredito) {
      return false;
    }
    return Boolean(this.mostrarBoton);
  }

  async connectedCallback() {
    const activeVentaId = this.currentVentaId;
    if (activeVentaId) {
      this.isLoading = true;
      try {
        const compraData = await getData({
          ventaId: activeVentaId,
          isFirstLoad: true
        });

        this.DataCompra = compraData;
        this.setData(compraData);
        this.step = 4;
        this.showResumen = true;

        await Promise.all([this.getAccount(), this.getObservaciones()]);
        await this.verificarNotasCreditoPendientes();
        await this.finish();

        if (PROMO_HT_FUTURA_HABILITADA) {
          setTimeout(() => {
            this.syncPromoQualificationState();
            this.refreshAllLinePromoPrices();
            this.notifyLineSaveStateChanged();
          }, 250);
        }
        const popupKey = "htPopup_" + activeVentaId;
        const popup = window.sessionStorage.getItem(popupKey);
        if (popup === "licencia") {
          this.isOpen2 = true;
        } else if (popup === "origen") {
          this.isOpen = true;
        }
        if (popup) {
          window.sessionStorage.removeItem(popupKey);
        }
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error("Error cargando compra desde Apex", e);
      } finally {
        this.isLoading = false;
      }
    }
  }

  computeHtFuturaPromoCantidadTotal() {
    if (
      !PROMO_HT_FUTURA_HABILITADA ||
      !isHtFuturaPromoScreen({
        semilleroId: this.semillero,
        cultivoName: this.cultivoNombre
      })
    ) {
      return 0;
    }
    return sumHtFuturaPromoEligibleQuantity(this.collectPromoLineData(), {
      semilleroId: this.semillero,
      cultivoName: this.cultivoNombre
    });
  }

  refreshAllLinePromoPrices() {
    if (!PROMO_HT_FUTURA_HABILITADA || !this.showResumen) {
      return;
    }
    const total = this.computeHtFuturaPromoCantidadTotal();
    this.template
      .querySelectorAll("c-crear-linea-venta-new")
      .forEach((line) => {
        line.refreshPromoPrice?.(total);
      });
  }

  async saveAllPendingLines() {
    this._savingAllPending = true;
    try {
      const children = Array.from(
        this.template.querySelectorAll("c-crear-linea-venta-new")
      );
      for (const child of children) {
        const rec = child.record;
        if (!rec?.Producto__c || !rec?.Cantidad__c) {
          continue;
        }
        if (!rec.Id || child.hasUnsavedChanges?.()) {
          await child.save(this.recordId, this.cultivo, this.productor.Id);
          this.assignSavedLineToChild(child);
        }
      }
      this.finalizePendingBatchSave();
    } finally {
      this._savingAllPending = false;
    }
  }

  get hasOperadorCobranza() {
    return this.productor && this.productor.Operador_de_Cobranza__r != null;
  }

  licensesList() {
    console.log(basePath);
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        pageName: "LicenciasListCustom__c"
      }
    });
  }

  async finalizar(options = {}) {
    const { mostrarModalExpediente = true } = options;
    const marcarRevisarCompra = this.shouldMarkRevisarCompra === true;
    this.shouldMarkRevisarCompra = false;
    this.finalizandoOperacion = true;

    try {
      try {
        this.isLoading = true;
        await this.saveAllPendingLines();
      } catch (e) {
        this.isLoading = false;
        return this.onError(
          "Error al guardar las lÃ­neas: " + (e.message || e)
        );
      }

      if (this.requiresTipoPago() && !this.tipoPago) {
        this.isLoading = false;
        this.pendingFinalizar = true;
        this.currentModal = "tipo-pago";
        return;
      }
      if (this.isChildrenLoading) {
        return this.onError("Espere a que se termine de guardar la lÃ­nea");
      }

      this.isLoading = true;
      const activeId = this.currentVentaId;

      try {
        const compraData = await getData({
          ventaId: activeId,
          isFirstLoad: true
        });
        this.DataCompra = compraData;

        const bloquearPorExpediente = await this.validarExpedienteDisponible(
          mostrarModalExpediente
        );
        if (bloquearPorExpediente) {
          this.pendingFinalizarPorExpediente = true;
          return;
        }
        this.pendingFinalizarPorExpediente = false;

        const guardar = await this.finish();

        if (guardar === false) {
          await this.procesarVentaIncompleta(activeId, marcarRevisarCompra);
          return;
        }

        await this.requestWrap(async () => {
          const data = await finalizarVenta({
            ventaId: activeId,
            checkDuplicates: activeId != this.lastDuplicateCheckId,
            origen: this.haveOrigenLegal,
            marcarRevisarCompra,
            blanqueo: this.Blanqueo
          });

          if (data.duplicate) {
            return this.notifyDuplicate();
          }

          this.setData(data);
          this.DataCompra = data;

          if (this.puedeFacturar) {
            await this.facturar();
          }

          this.currentModal = data.pendiente
            ? "Pendiente de FacturaciÃ³n"
            : "finalizada";
          await this.getAccount();
          this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
              url: `${basePath}/venta-ht/${activeId}`
            }
          });
        });
      } catch (e) {
        this.onError(e);
      } finally {
        this.isLoading = false;
      }
    } finally {
      this.finalizandoOperacion = false;
    }
  }

  async procesarVentaIncompleta(activeId, marcarRevisarCompra = false) {
    await this.requestWrap(async () => {
      const data = await finalizarVenta({
        ventaId: activeId,
        checkDuplicates: activeId != this.lastDuplicateCheckId,
        origen: this.haveOrigenLegal,
        marcarRevisarCompra,
        blanqueo: this.Blanqueo
      });

      if (data.duplicate) {
        return this.notifyDuplicate();
      }

      this.setData(data);
      this.DataCompra = data;
      this.currentModal = data.pendiente
        ? "Pendiente de FacturaciÃ³n"
        : "finalizada";
      await this.getAccount();

      if (this.haveLicence === false) {
        window.sessionStorage.setItem("htPopup_" + activeId, "licencia");
        this.isOpen2 = true;
      } else if (this.haveOrigenLegal === false && this.haveLicence === true) {
        window.sessionStorage.setItem("htPopup_" + activeId, "origen");
        this.isOpen = true;
      }
    });
  }

  notifyDuplicate() {
    this.currentModal = "duplicate-venta";
    this.lastDuplicateCheckId = this.currentVentaId;
  }

  async anular() {
    await this.requestWrap(async () => {
      const data = await anular({ ventaId: this.recordId });
      this.setData(data);
      this.currentModal = null;
      this.redirectPendientesFacturacion();
    });
  }

  async search(event) {
    const lookup = event.target;
    await searchProductores(event.detail)
      .then((res) => lookup.setSearchResults(res))
      .catch((e) => this.onError(e));
  }

  getSemilleroData() {
    return getSemilleroData({
      obtentorId: this.semillero,
      productorId: this.productor.Id
    });
  }

  async getProductos() {
    await this.requestWrap(async () => {
      const products = await getProductsData({
        cultivoId: this.cultivo,
        productorId: this.productor.Id
      });
      this.updateVariedades(products);
    });
  }

  openFileUpload() {
    this.showFileUploadModal = true;
  }

  async updateOpp() {
    await updateOpportunity({
      recordId: this.recordId,
      fechaEmision: this.formattedDate,
      numComprobante: this.customCode
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Ã‰xito",
            message: `Factura ${this.customCode} guardada correctamente`,
            variant: "success"
          })
        );
        this.isLoading = false;
      })
      .catch(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "error",
            message: "Error al guardar la factura",
            variant: "error"
          })
        );
      });
  }

  closeFileUpload() {
    this.showFileUploadModal = false;
  }
  get acceptedFormats() {
    return [".pdf"];
  }

  handleSave() {
    if (this.formattedDate != null && this.customCode != null) {
      this.isLoading = true;
      this.updateOpp();
      this.closeFileUpload();
    } else {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message:
            "Debe completar correctamente los campos NÂ° de Comprobante y Fecha de emisiÃ³n",
          variant: "error"
        })
      );
    }
  }

  handleUploadFinished(event) {
    const uploadedFiles = event.detail.files;

    if (uploadedFiles.length > 1) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Solo se permite subir un archivo PDF",
          variant: "error"
        })
      );
      return;
    }

    const file = uploadedFiles[0];
    const isValidExtension = file.name.toLowerCase().endsWith(".pdf");
    const isValidMimeType = file.mimeType === "application/pdf";

    if (!isValidExtension || !isValidMimeType) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: `El archivo "${file.name}" no es un PDF vÃ¡lido. Solo se permiten archivos PDF.`,
          variant: "error"
        })
      );
      return;
    }

    this.dispatchEvent(
      new ShowToastEvent({
        title: "Ã‰xito",
        message: `Archivo PDF "${file.name}" subido correctamente`,
        variant: "success"
      })
    );
  }

  // ===== NavegaciÃ³n de pasos =====
  step = 1;
  get step1Class() {
    return (
      "step" + (this.step === 1 ? " active" : this.step > 1 ? " completed" : "")
    );
  }
  get step2Class() {
    return (
      "step" + (this.step === 2 ? " active" : this.step > 2 ? " completed" : "")
    );
  }
  get step3Class() {
    return (
      "step" + (this.step === 3 ? " active" : this.step > 3 ? " completed" : "")
    );
  }
  get step4Class() {
    return "step" + (this.step === 4 ? " active" : "");
  }
  get isStep1Active() {
    return this.step === 1;
  }
  get isStep2Active() {
    return this.step === 2;
  }
  get isStep3Active() {
    return this.step === 3;
  }
  get isStep4Active() {
    return this.step === 4;
  }

  handleStepClick(event) {
    const clickedStep = Number(event.currentTarget.dataset.step);
    if (clickedStep <= this.step) this.step = clickedStep;
  }

  cultivoSelected(event) {
    this.cultivo = event.detail.value;
    if (this.cultivo) this.step = 2;
  }

  productorSelected(event) {
    const selection = event.target.getSelection();
    this.productor = selection.length ? selection[0].record : null;
    if (this.productor) {
      this.step = 3;
      this.getProductos();
    }
  }

  get tiposCompraDisponibles() {
    const tipos = new Set();
    Object.values(this.variedadesByObtentor || {}).forEach((entries) => {
      entries.forEach((v) => {
        if (v.record?.Product2?.Tipo_de_Compra__c) {
          tipos.add(v.record.Product2.Tipo_de_Compra__c);
        }
      });
    });
    return Array.from(tipos);
  }

  get filteredSemilleros() {
    if (!this.tipoCompraSeleccionado) return this.semilleros;
    return (this.semilleros || []).filter((s) => {
      const entries = this.variedadesByObtentor?.[s.value] || [];
      return entries.some(
        (v) =>
          v.record?.Product2?.Tipo_de_Compra__c === this.tipoCompraSeleccionado
      );
    });
  }

  get decoratedTiposCompra() {
    const disponibles = this.tiposCompraDisponibles;
    const opciones = [
      {
        value: "Futura",
        label: "HT Futura",
        description:
          "Se trata de las HT que son precertificables dentro de los plazos del programa y la conversiÃ³n a toneladas se produce a partir de la entrega de grano."
      },
      {
        value: "Disponible",
        label: "HT Disponible",
        description:
          "Se trata de las HT que acreditan inmediatamente toneladas. SÃ³lo se pueden adquirir antes de la entrega de grano. No son precertificables."
      }
    ];
    return opciones
      .filter((o) => disponibles.includes(o.value))
      .map((o) => ({
        ...o,
        cssClass:
          "tipo-card" +
          (this.tipoCompraSeleccionado === o.value ? " selected" : "")
      }));
  }

  handleSelectTipoCompra(event) {
    const tipo = event.currentTarget.dataset.tipo;
    if (!tipo) return;
    this.tipoCompraSeleccionado = tipo;
    this.Futura = tipo === "Futura";
    this.step = 4;
  }

  get variedades() {
    const todas = this.variedadesByObtentor?.[this.semillero] || [];
    if (!this.tipoCompraSeleccionado) return todas;
    return todas.filter(
      (v) =>
        v.record?.Product2?.Tipo_de_Compra__c === this.tipoCompraSeleccionado
    );
  }

  semilleroSelected(event) {
    this.semillero = event.detail;
    this.showResumen = true;
  }

  semilleroSelectedEjecuto(event) {
    this.semillero = event.detail;
    this.getProductos();
    this.step = 4;
    this.showResumen = true;
    if (PROMO_HT_FUTURA_HABILITADA) {
      setTimeout(() => {
        this.syncPromoQualificationState();
        this.refreshAllLinePromoPrices();
      }, 250);
    }
  }

  get decoratedCultivos() {
    return (this.cultivos || []).map((c) => {
      const nombre = c.label;
      const id = c.value;
      return {
        ...c,
        nombre,
        id,
        icono: this.getIcon(nombre),
        cssClass:
          "item" + (this.cultivoSeleccionadoId === id ? " selected" : "")
      };
    });
  }

  getIcon(nombre) {
    switch ((nombre || "").toLowerCase()) {
      case "soja":
        return this.iconSojaHTUrl;
      case "trigo":
        return this.iconTrigoHTUrl;
      case "cebada":
        return this.iconCebadaUrl;
      default:
        return "";
    }
  }

  handleSelectCultivo(event) {
    const cultivoId = event.currentTarget.dataset.id;
    this.cultivo = cultivoId;
    this.cultivoSeleccionadoId = cultivoId;
    console.log("Cultivo seleccionado: ", cultivoId);
    console.log("Cultivo seleccionado: ", this.cultivoName);
    this.step = 2;
  }

  handleTipoHtChange(event) {
    const { isFutura } = event.detail;
    this.Futura = event.detail.isFutura;
    if (PROMO_HT_FUTURA_HABILITADA) {
      this.syncPromoQualificationState();
      Promise.resolve().then(() => this.refreshAllLinePromoPrices());
    }
  }

  handlePromoLineChange(event) {
    if (!PROMO_HT_FUTURA_HABILITADA) {
      return;
    }
    if (event?.detail?.evalModal === true) {
      const immediate = event?.detail?.immediate === true;
      scheduleHtFuturaPromoEval(
        this,
        () => this.evaluarCondicionPromocionalHtFutura(),
        { immediate }
      );
      return;
    }
    Promise.resolve().then(() => {
      this.refreshAllLinePromoPrices();
      this.notifyLineSaveStateChanged();
    });
  }

  disconnectedCallback() {
    if (PROMO_HT_FUTURA_HABILITADA) {
      cancelHtFuturaPromoEval(this);
    }
  }

  collectPromoLineData() {
    const rows = Array.from(
      this.template.querySelectorAll("c-crear-linea-venta-new")
    );
    if (rows.length) {
      return rows.map((row) => row.getPromoLineData()).filter(Boolean);
    }

    const records = this.data?.record?.Lineas_de_Venta_HT__r || [];
    return records
      .map((record) => ({
        tipoCompra: record.Producto__r?.Tipo_de_Compra__c,
        cantidad: record.Cantidad__c,
        listPrice: resolveBaseListPrice(record.Precio_de_Lista__c)
      }))
      .filter((line) => line.tipoCompra && line.listPrice != null);
  }

  computePromoQualification() {
    if (
      !PROMO_HT_FUTURA_HABILITADA ||
      !isHtFuturaPromoScreen({
        semilleroId: this.semillero,
        cultivoName: this.cultivoNombre
      })
    ) {
      return false;
    }

    const lineas = this.collectPromoLineData();
    return qualifiesForHtFuturaPromoAggregate({
      lineas,
      semilleroId: this.semillero,
      cultivoName: this.cultivoNombre
    });
  }

  syncPromoQualificationState() {
    if (!PROMO_HT_FUTURA_HABILITADA) {
      return;
    }
    if (
      !isHtFuturaPromoScreen({
        semilleroId: this.semillero,
        cultivoName: this.cultivoNombre
      })
    ) {
      this.resetHtFuturaPromoUi();
      return;
    }
    this.htFuturaPromoPreviouslyQualified = this.computePromoQualification();
  }

  evaluarCondicionPromocionalHtFutura() {
    if (!PROMO_HT_FUTURA_HABILITADA) {
      return;
    }
    if (
      !isHtFuturaPromoScreen({
        semilleroId: this.semillero,
        cultivoName: this.cultivoNombre
      })
    ) {
      this.resetHtFuturaPromoUi();
      return;
    }

    this.updatePromoMessage(this.computePromoQualification());
    this.refreshAllLinePromoPrices();
  }

  resetHtFuturaPromoUi() {
    cancelHtFuturaPromoEval(this);
    this.htFuturaPromoMessage = null;
    this.htFuturaPromoPreviouslyQualified = false;
    this.htFuturaPromoCelebrationShown = false;
    if (this.currentModal === "ht-futura-promo") {
      this.currentModal = null;
    }
  }

  updatePromoMessage(hasQualifying) {
    const hadBefore = this.htFuturaPromoPreviouslyQualified;
    const ui = resolveHtFuturaPromoUiState({
      hasQualifying,
      hadQualifying: hadBefore,
      celebrationAlreadyShown: this.htFuturaPromoCelebrationShown,
      currentModalIsPromo: this.currentModal === "ht-futura-promo"
    });

    if (ui.showCelebrationModal || ui.showLossModal) {
      this.htFuturaPromoMessage = ui.promoMessage;
      this.htFuturaPromoVariant = ui.promoVariant;
      this.currentModal = "ht-futura-promo";
      if (ui.showCelebrationModal) {
        this.htFuturaPromoCelebrationShown = ui.celebrationAlreadyShown;
      }
    } else if (ui.dismissPromoModal) {
      this.currentModal = null;
      this.htFuturaPromoMessage = null;
    }

    this.htFuturaPromoPreviouslyQualified = hasQualifying;
  }

  handleInsertarObs() {
    this.showObsModal = true;
  }

  handleObsSave() {
    const textarea = this.template.querySelector("lightning-textarea");
    const obs = textarea ? textarea.value : "";
    if (!obs || obs.trim() === "") {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Por favor ingrese observaciones",
          variant: "error"
        })
      );
      return;
    }

    this.isLoading = true;
    saveObvservations({ recordId: this.recordId, obs })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Ã‰xito",
            message: "Observaciones guardadas correctamente",
            variant: "success"
          })
        );
        this.handleObsCloseModal();
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: error.body?.message || "Error al guardar",
            variant: "error"
          })
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleObsCloseModal() {
    this.showObsModal = false;
  }

  async getObservaciones() {
    try {
      this.observaciones = await getObservaciones({ recordId: this.recordId });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Error obteniendo observaciones:", error);
    }
  }

  async finish() {
    let poseeLicencia = false;
    const variedades = [];

    if (!this.DataCompra || !this.DataCompra.record) {
      return false;
    }

    if (this.DataCompra.semilleroData?.licencia?.Id) {
      poseeLicencia = true;
    }

    const lineasVenta = this.DataCompra.record.Lineas_de_Venta_HT__r || [];
    lineasVenta.forEach((element) => {
      if (element.Producto__r?.Variedad2__c) {
        variedades.push(element.Producto__r.Variedad2__c);
      }
    });

    try {
      const res = await canFinish({
        semillero: this.DataCompra.semilleroData?.semillero || {},
        CuentaProductor: this.DataCompra.record.Cuenta_Productor__r?.Id,
        tieneLicencia: poseeLicencia,
        Variedades: variedades
      });

      this.haveLicence = res.TieneLicencia;
      this.haveOrigenLegal = res.origenLegal;
      this.Blanqueo = res.Blanqueo;

      if (res.origenLegal === true && res.TieneLicencia === true) {
        return true;
      }
      if (
        res.TieneLicencia === true &&
        res.origenLegal === false &&
        res.Blanqueo === true
      ) {
        return true;
      }
      return false;
    } catch (error) {
      console.error(
        "Error crÃ­tico al ejecutar validaciones (canFinish):",
        error
      );
      return false;
    }
  }

  async getAccount() {
    try {
      this.mostrarBoton = await getAccountFromUserByVenta({
        ventaId: this.currentVentaId
      });
    } catch (error) {
      console.error("Error obteniendo cuenta de usuario:", error);
      this.mostrarBoton = false;
    }
  }

  requiresTipoPago() {
    return (
      ["03", "14", "85"].includes(this.semillero) &&
      this.cultivoNombre === "SOJA"
    );
  }

  async handleTipoPagoSelected(event) {
    const value = event?.detail?.value; // 'Contado' | 'Financiado'
    if (!value) return;

    this.tipoPago = value;

    await this.requestWrap(async () => {
      const data = await updateTipoPago({
        ventaId: this.recordId,
        tipoPago: value
      });
      this.setData(data);
      this.DataCompra = data;
    });

    // cierra modal tipo-pago
    this.currentModal = null;

    // si venÃ­a de apretar finalizar, continÃºa
    if (this.pendingFinalizar) {
      this.pendingFinalizar = false;
      await this.finalizar(); // ahora ya pasa el gate porque this.tipoPago existe
    }
  }

  async validarExpedienteDisponible(mostrarModalSiTieneExpediente = true) {
    const activeId = this.currentVentaId;
    if (!activeId) {
      return false;
    }
    if (OMITIR_MODAL_ALERTA_EXPEDIENTE_NEGATIVO) {
      return false;
    }
    try {
      const result = await verificarExpedienteEnHTDisponible({
        compraVentaId: activeId,
        tipoOperacion: "venta"
      });
      // eslint-disable-next-line no-console
      console.log(
        "[CrearVenta2] verificarExpedienteEnHTDisponible result:",
        JSON.stringify(result)
      );
      if (Boolean(result?.tieneExpediente) && mostrarModalSiTieneExpediente) {
        this.currentModal = "expediente-disponible-alert";
        return true;
      }
      return false;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(
        "Error validando expediente en HT disponible (venta):",
        error
      );
      return false;
    }
  }

  // ===== MÃ‰TODOS PARA NOTAS DE CRÃ‰DITO PARCIAL (precio y cantidad) =====

  async verificarNotasCreditoPendientes() {
    try {
      if (this.currentVentaId) {
        const resultado = await verificarNotasCreditoPendientes({
          ventaId: this.currentVentaId
        });
        this.infoNotasCredito = resultado;
        if (resultado.tieneNotasCreditoPendientes) {
          this.notasCreditoPendientes = resultado.detalleNotas || [];
          this.mostrarAlertaNotaCredito = true;
        }
      }
    } catch (error) {
      console.error("Error al verificar notas de crÃ©dito:", error);
    }
  }

  cerrarAlertaNotaCredito() {
    this.mostrarAlertaNotaCredito = false;
  }

  navegarANotaCredito(event) {
    const notaCreditoId = event.currentTarget.dataset.id;
    if (notaCreditoId) {
      const url = `${basePath}/venta-ht/${notaCreditoId}/${notaCreditoId}`;
      this[NavigationMixin.Navigate]({
        type: "standard__webPage",
        attributes: { url }
      });
    }
  }

  navegarAVentaOriginal() {
    if (this.ventaOriginalId) {
      const url = `${basePath}/venta-ht/${this.ventaOriginalId}/${this.ventaOriginalName || this.ventaOriginalId}`;
      this[NavigationMixin.Navigate]({
        type: "standard__webPage",
        attributes: { url }
      });
    }
  }

  handleNCMenuSelect(event) {
    const value = event.detail.value;
    if (value === "NC_Total") {
      this.mostrarConfirmacionNCTotal();
    } else if (value === "NC_Precio") {
      this.activarNotaCreditoPrecio();
    } else if (value === "NC_Cantidad") {
      this.activarNotaCreditoCantidad();
    }
  }

  mostrarConfirmacionNCTotal() {
    this.showConfirmNCTotalModal = true;
  }

  confirmarNCTotal() {
    this.showConfirmNCTotalModal = false;
    this.crearNotaCreditoTotal();
  }

  cancelarNCTotal() {
    this.showConfirmNCTotalModal = false;
  }

  activarNotaCreditoPrecio() {
    this.modoNotaCreditoPrecio = true;
    this.modoNotaCreditoCantidad = false;
    this.botonProcesarNCVisible = true;
    this.resetearSeleccionNC();
  }

  activarNotaCreditoCantidad() {
    this.modoNotaCreditoCantidad = true;
    this.modoNotaCreditoPrecio = false;
    this.botonProcesarNCVisible = true;
    this.resetearSeleccionNC();
  }

  resetearSeleccionNC() {
    this.lineasSeleccionadasNC = [];
    this.template
      .querySelectorAll("c-crear-linea-venta-new3")
      .forEach((child) => {
        child.resetearSeleccionNC();
      });
  }

  cancelarNotaCredito() {
    this.resetearModosNC();
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Cancelado",
        message: this.labels.ncModeCanceled,
        variant: "info"
      })
    );
  }

  resetearModosNC() {
    this.modoNotaCreditoPrecio = false;
    this.modoNotaCreditoCantidad = false;
    this.botonProcesarNCVisible = false;
    this.observacionesLineasNC = {};
    this.resetearSeleccionNC();
  }

  handleCheckboxChange(event) {
    const lineaId = event.detail.lineaId;
    const isChecked = event.detail.checked;
    if (isChecked) {
      this.lineasSeleccionadasNC.push(lineaId);
    } else {
      this.lineasSeleccionadasNC = this.lineasSeleccionadasNC.filter(
        (id) => id !== lineaId
      );
    }
  }

  handlePrecioChange(event) {
    // Validaciones delegadas al hijo
  }

  handleCantidadChange(event) {
    // Validaciones delegadas al hijo
  }

  handleObservacionesChange(event) {
    const lineaId = event.detail.lineaId;
    const observaciones = event.detail.observaciones;
    this.observacionesLineasNC = {
      ...this.observacionesLineasNC,
      [lineaId]: observaciones
    };
  }

  async procesarNotaCreditoParcial() {
    if (this.lineasSeleccionadasNC.length === 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: this.labels.ncNoLinesSelected,
          variant: "error"
        })
      );
      return;
    }

    const lineasSinObservaciones = [];
    for (const lineaId of this.lineasSeleccionadasNC) {
      if (
        !this.observacionesLineasNC[lineaId] ||
        this.observacionesLineasNC[lineaId].trim() === ""
      ) {
        lineasSinObservaciones.push(lineaId);
      }
    }
    if (lineasSinObservaciones.length > 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: this.labels.ncAllObservacionesRequired,
          variant: "error"
        })
      );
      return;
    }

    this.isLoading = true;
    try {
      const lineasConAjustes = [];
      const componentesHijos = this.template.querySelectorAll(
        "c-crear-linea-venta-new3"
      );
      for (const componente of componentesHijos) {
        if (this.lineasSeleccionadasNC.includes(componente.record.Id)) {
          const ajuste = componente.obtenerDatosAjusteNC();
          if (ajuste && ajuste.lineaId) {
            lineasConAjustes.push({
              lineaId: ajuste.lineaId,
              tipoAjuste: ajuste.tipoAjuste,
              valorAnterior: Number(ajuste.valorAnterior),
              valorNuevo: Number(ajuste.valorNuevo),
              observaciones: this.observacionesLineasNC[ajuste.lineaId]
            });
          }
        }
      }

      if (lineasConAjustes.length === 0) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: "No se encontraron datos vÃ¡lidos para procesar",
            variant: "error"
          })
        );
        return;
      }

      let resultado;
      if (this.modoNotaCreditoPrecio) {
        resultado = await procesarNotaCreditoParcialPrecio({
          ventaId: this.recordId,
          lineasConAjustes: JSON.stringify(lineasConAjustes)
        });
      } else if (this.modoNotaCreditoCantidad) {
        resultado = await procesarNotaCreditoParcialCantidad({
          ventaId: this.recordId,
          lineasConAjustes: JSON.stringify(lineasConAjustes)
        });
      }

      if (resultado) {
        const mensajeExito = this.labels.ncProcessSuccess
          .replace("{0}", resultado.notaCreditoName)
          .replace("{1}", resultado.lineasCreadas);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Ã‰xito",
            message: mensajeExito,
            variant: "success"
          })
        );
        this.resetearModosNC();
        await this.recargarDatos();
      }
    } catch (error) {
      console.error("Error al procesar nota de crÃ©dito:", error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Error al procesar nota de crÃ©dito",
          variant: "error"
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  async recargarDatos() {
    try {
      const compraData = await getData({
        ventaId: this.currentVentaId,
        isFirstLoad: true
      });
      this.DataCompra = compraData;
      this.setData(compraData);
      await this.verificarNotasCreditoPendientes();
    } catch (error) {
      this.onError(error);
    }
  }
}
