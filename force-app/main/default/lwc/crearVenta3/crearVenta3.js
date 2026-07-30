import { LightningElement, api, track } from "lwc";
import { CompraVentaMixin } from "c/utilsHT";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import searchProductores from "@salesforce/apex/CrearVentaController2.searchProductores";
import getData from "@salesforce/apex/CrearVentaController2.getData";
import updateOpportunity from "@salesforce/apex/CrearVentaController2.updateOpportunity";
import finalizarVenta from "@salesforce/apex/CrearVentaController2.finalizarVenta";
import anular from "@salesforce/apex/CrearVentaController2.anular";
import getSemilleroData from "@salesforce/apex/CrearVentaController2.getSemilleroData";
import canFinish from "@salesforce/apex/CrearVentaController2.canFinish";
import getProductsData from "@salesforce/apex/CrearVentaController2.getProductsData";
import getObservaciones from "@salesforce/apex/CrearVentaController2.getObservaciones";
import saveObvservations from "@salesforce/apex/CrearVentaController2.saveObvservations";
import getAccountFromUser from "@salesforce/apex/UtilsVentaHt.getAccountFromUser";
import { NavigationMixin } from "lightning/navigation";
import basePath from "@salesforce/community/basePath";
import icons from "c/icons";
import resourcePortal from "@salesforce/resourceUrl/resourcePortal";
import procesarNotaCreditoParcialPrecio from "@salesforce/apex/CrearVentaController2.crearNotaCreditoParcialPrecio";
// AGREGAR import para el nuevo método Apex por cantidad
import procesarNotaCreditoParcialCantidad from "@salesforce/apex/CrearVentaController2.crearNotaCreditoParcialCantidad";
// AGREGAR después de los otros imports
import verificarNotasCreditoPendientes from "@salesforce/apex/CrearVentaController2.verificarNotasCreditoPendientes";
// AGREGAR imports de Custom Labels
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
import NC_ADD_VARIETY from "@salesforce/label/c.NC_Add_Variety";
import NC_FINALIZE_SALE from "@salesforce/label/c.NC_Finalize_Sale";
import NC_UPLOAD_INVOICE from "@salesforce/label/c.NC_Upload_Invoice";
import NC_OBSERVACIONES_BUTTON from "@salesforce/label/c.NC_Observaciones_Button";
import NC_NEW_SALE from "@salesforce/label/c.NC_New_Sale";
import NC_ANULAR_BUTTON from "@salesforce/label/c.NC_Anular_Button";
import NC_FACTURAR_BUTTON from "@salesforce/label/c.NC_Facturar_Button";
import NC_NEW_PRICE_LABEL from "@salesforce/label/c.NC_New_Price_Label";
import NC_NEW_QUALITY_LABEL from "@salesforce/label/c.NC_New_Quantity_Label";
import NC_OBSERVACIONES_LABEL from "@salesforce/label/c.NC_Observaciones_Label";
import NC_OBSERVACIONES_TOOLTIP from "@salesforce/label/c.NC_Observaciones_Tooltip";
import NC_SELECT_LABEL from "@salesforce/label/c.NC_Select_Label";
import NC_CONFIRM_MODAL_TITLE from "@salesforce/label/c.NC_Confirm_Modal_Title";
import NC_CONFIRM_MODAL_MESSAGE from "@salesforce/label/c.NC_Confirm_Modal_Message";
import NC_CONFIRM_MODAL_CONFIRM from "@salesforce/label/c.NC_Confirm_Modal_Confirm";

export default class CrearVenta3 extends CompraVentaMixin(LightningElement) {
  iconCebadaUrl = `${resourcePortal}/resourcePortal/images/prd-cebada.svg`;
  iconSojaHTUrl = `${resourcePortal}/resourcePortal/images/prd-soja.svg`;
  iconTrigoHTUrl = `${resourcePortal}/resourcePortal/images/prd-trigo.svg`;
  iconVenderHTUrl = `${resourcePortal}/resourcePortal/images/icon-vender-ht.svg`;
  iconCondicionesHTUrl = `${resourcePortal}/resourcePortal/images/icon-condiciones.svg`;
  // ✅ AGREGAR propiedad para almacenar labels
  labels = {
    ncObservacionesLabel: NC_OBSERVACIONES_LABEL,
    ncSelectLabel: NC_SELECT_LABEL,
    ncObservacionesTooltip: NC_OBSERVACIONES_TOOLTIP,
    ncNewQualityLabel: NC_NEW_QUALITY_LABEL,
    ncNewPriceLabel: NC_NEW_PRICE_LABEL,
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
    ncAddVariety: NC_ADD_VARIETY,
    ncFinalizeSale: NC_FINALIZE_SALE,
    ncUploadInvoice: NC_UPLOAD_INVOICE,
    ncObservacionesButton: NC_OBSERVACIONES_BUTTON,
    ncNewSale: NC_NEW_SALE,
    ncAnularButton: NC_ANULAR_BUTTON,
    ncFacturarButton: NC_FACTURAR_BUTTON,
    ncConfirmModalTitle: NC_CONFIRM_MODAL_TITLE,
    ncConfirmModalMessage: NC_CONFIRM_MODAL_MESSAGE,
    ncConfirmModalConfirm: NC_CONFIRM_MODAL_CONFIRM
  };
  // AGREGAR getter para el mensaje de alerta
  get mensajeAlertaNotaCredito() {
    if (!this.infoNotasCredito || !this.labels.ncAlertMessage) {
      return `Existe ${this.infoNotasCredito?.cantidadPendientes || 0} nota(s) de crédito pendiente(s) de facturación. Debe procesar la facturación antes de crear nuevas notas de crédito.`;
    }

    // ✅ Reemplazar parámetro de forma segura
    return this.labels.ncAlertMessage.replace(
      "{0}",
      this.infoNotasCredito.cantidadPendientes || 0
    );
  }

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
  @track showConfirmNCTotalModal = false;
  @track haveLicence;
  @track haveOrigenLegal;
  @track Futura;

  formattedDate = null;
  customCode = null;

  subscription = null;
  @track isModalOpen = false;
  @track isLoading = false;
  @track modoNotaCreditoPrecio = false;
  @track modoNotaCreditoCantidad = false;
  @track lineasSeleccionadasNC = [];
  @track botonProcesarNCVisible = false;
  @track observacionesLineasNC = {}; // Objeto para almacenar observaciones por línea
  // @track showFinanciamientoColumn = false;
  // AGREGAR nuevas propiedades
  @track infoNotasCredito = {};
  @track mostrarAlertaNotaCredito = false;
  @track notasCreditoPendientes = [];
  @track todasLasNC = [];
  icons = icons.compraVenta;

  // ===== CONTROL DE ESTADO PARA BOTONES FACTURA/OBS =====
  get isPendienteLicencias() {
    // 1) Flag que devuelve Apex al finalizar
    if (this.data?.pendiente === true) return true;

    // 2) Si alguna línea/registro está “Pendiente”
    try {
      return (this.items || []).some((i) => {
        const est = (
          i?.record?.Estado__c ||
          i?.factura?.Estado__c ||
          ""
        ).toLowerCase();
        return est.includes("pendiente");
      });
    } catch (_e) {
      return false;
    }
  }

  get mostrarFacturaYObs() {
    return (
      Boolean(this.mostrarBoton) &&
      !this.isPendienteLicencias &&
      !this.esNotaCredito
    );
  }
  // =======================================================

  // MODIFICAR propiedades computadas
  get puedeCrearNotaCreditoParcial() {
    return (
      this.data.record &&
      this.data.record.Estado__c == "Facturada" /*||
        this.data.record.Estado__c == "Pagada"*/ &&
      (this.data.record.Obtentor__r.Id_Obtentor__c == "03" ||
        this.data.record.Obtentor__r.Id_Obtentor__c == "14" ||
        this.data.record.Obtentor__r.Id_Obtentor__c == "85") &&
      !this.infoNotasCredito?.existeNCTotal
    );
  }

  get puedeCrearNotaCreditoPrecio() {
    return (
      this.puedeCrearNotaCreditoParcial &&
      !this.infoNotasCredito?.existeNCPPendiente &&
      !this.infoNotasCredito?.existeNCCPendiente
    );
  }

  get puedeCrearNotaCreditoCantidad() {
    return (
      this.puedeCrearNotaCreditoParcial &&
      !this.infoNotasCredito?.existeNCCPendiente &&
      !this.infoNotasCredito?.existeNCPPendiente
    );
  }

  get mostrarMenuNC() {
    return (
      this.puedeCrearNotaCredito ||
      this.puedeCrearNotaCreditoPrecio ||
      this.puedeCrearNotaCreditoCantidad
    );
  }

  get tieneNCTotal() {
    return this.puedeCrearNotaCredito;
  }
  get tieneNCPrecio() {
    return this.puedeCrearNotaCreditoPrecio;
  }
  get tieneNCCantidad() {
    return this.puedeCrearNotaCreditoCantidad;
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

  get mostrarBotonNotaCredito() {
    return this.puedeCrearNotaCreditoParcial && !this.mostrarCamposNotaCredito;
  }
  get mostrarCamposNotaCredito() {
    return this.modoNotaCreditoPrecio || this.modoNotaCreditoCantidad;
  }

  get textoBotonProcesarNC() {
    if (this.modoNotaCreditoPrecio) return this.labels.ncProcessPrice;
    if (this.modoNotaCreditoCantidad) return this.labels.ncProcessQuantity;
    return this.labels.ncProcessGeneric;
  }

  // ✅ PROPIEDAD COMPUTADA: Tipo de Nota de Crédito a nivel de VENTA
  get tipoNotaCredito() {
    if (!this.data.record) {
      return "";
    }

    const venta = this.data.record;
    console.log("🔍 DEBUG - tipoNotaCredito - venta:", {
      Es_NC__c: venta.Es_NC__c,
      Tipo_Ajuste__c: venta.Tipo_Ajuste__c
    });

    if (venta.Es_NC__c && venta.Tipo_Ajuste__c) {
      switch (venta.Tipo_Ajuste__c) {
        case "NC":
          return "NC Total";
        case "NCP":
          return "NCP Precio";
        case "NCC":
          return "NCC Cantidad";
        default:
          return venta.Tipo_Ajuste__c;
      }
    }
    return "";
  }

  // ✅ PROPIEDAD COMPUTADA: Clase CSS para el badge
  get tipoNotaCreditoClass() {
    if (!this.tipoNotaCredito) return "";

    switch (this.tipoNotaCredito) {
      case "NC Total":
        return "badge-nc-total";
      case "NCP Precio":
        return "badge-ncp-precio";
      case "NCC Cantidad":
        return "badge-ncc-cantidad";
      default:
        return "badge-nc-default";
    }
  }

  // ✅ PROPIEDAD COMPUTADA: Determina si la venta es Nota de Crédito
  get esNotaCredito() {
    return this.data.record && this.data.record.Es_NC__c === true;
  }
  // ✅ MODIFICAR propiedades existentes para ocultar botones cuando es NC
  get puedeAnular() {
    // ❌ NO se puede anular si es Nota de Crédito
    if (this.esNotaCredito) return false;
    return (
      this.data &&
      this.data.record &&
      this.data.record.Estado__c == "Pendiente de Facturación"
    );
  }

  get puedeRealizarNueva() {
    // ❌ NO se puede crear nueva venta si es Nota de Crédito
    if (this.esNotaCredito) return false;
    return this.recordId && !this.puedeEditar && !this.puedeFacturar;
  }
  get puedeAgregarVariedad() {
    // ❌ NO se puede anular si es Nota de Crédito
    if (this.esNotaCredito) return false;
  }

  // ✅ PROPIEDAD COMPUTADA: Determina si mostrar la columna Tipo NC
  get mostrarColumnaTipoNC() {
    return this.tipoNotaCredito !== "";
  }

  // AGREGAR método para verificar notas de crédito
  async verificarNotasCreditoPendientes() {
    try {
      if (this.recordId) {
        const resultado = await verificarNotasCreditoPendientes({
          ventaId: this.recordId
        });
        this.infoNotasCredito = resultado;

        if (resultado.tieneNotasCreditoPendientes) {
          this.notasCreditoPendientes = resultado.detalleNotas || [];
          this.mostrarAlertaNotaCredito = true;

          console.log(
            "Notas de crédito pendientes encontradas:",
            this.notasCreditoPendientes
          );

          // Mostrar toast informativo
          /*this.dispatchEvent(new ShowToastEvent({
                    title: 'Nota de Crédito Pendiente',
                    message: `Existe ${resultado.cantidadPendientes} nota(s) de crédito pendiente(s) de facturación`,
                    variant: 'warning',
                    mode: 'dismissable'
                }));*/
        }
      }
    } catch (error) {
      console.error("Error al verificar notas de crédito:", error);
    }
  }

  // MODIFICAR connectedCallback para incluir verificación
  async connectedCallback() {
    this.template.addEventListener(
      "openmodal",
      this.handleOpenModal.bind(this)
    );

    if (this.pageRecordId) {
      this.isLoading = true;
      try {
        const compraData = await getData({
          ventaId: this.pageRecordId,
          isFirstLoad: true
        });
        this.DataCompra = compraData;
        this.setData(compraData);
        this.step = 3;
        this.showResumen = true;
        await this.getAccount();
        await this.getObservaciones();
        await this.verificarNotasCreditoPendientes(); // NUEVA LLAMADA
        this.finish();
        const popupKey = "htPopup_" + this.pageRecordId;
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
        console.error("Error cargando compra desde Apex", e);
      } finally {
        this.isLoading = false;
        console.log("this.data.record", JSON.stringify(this.data.record));
      }
    }
  }
  // AGREGAR método para cerrar alerta
  cerrarAlertaNotaCredito() {
    this.mostrarAlertaNotaCredito = false;
  }

  // AGREGAR método para navegar a nota de crédito
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

  // ===== Validaciones de inputs de factura =====
  ValidateData() {
    this.uploadFactura = !(
      this.formattedDate &&
      this.customCode &&
      this.formattedDate !== "" &&
      this.customCode !== ""
    );
  }

  handleDateChange(event) {
    const rawDate = event.target.value; // yyyy-mm-dd
    const [y, m, d] = rawDate.split("-");
    this.formattedDate = `${y}-${m}-${d}`;
    this.ValidateData();
  }

  handleCodeChange(event) {
    const value = event.target.value;
    const regex = /^[ABC]-\d{4,5}-\d{8}$/;
    this.customCode = regex.test(value) ? value : null;
    this.ValidateData();
  }
  // =============================================

  handleLoadingChange(event) {
    this.isLoading = event.detail.isLoading;
  }

  handleOpenModal() {
    this.isModalOpen = true;
  }
  closeModal() {
    this.isOpen = false;
    this.isOpen2 = false;
    this.currentModal = null;
  }
  handleKeyDown() {} // stub para el modal de obs

  handleSemilleroIconReady(event) {
    this.semilleroIcono = event.detail;
  }

  getData(isFirstLoad) {
    return getData({ ventaId: this.recordId, isFirstLoad });
  }

  setData(data) {
    this.setDataAndItems(
      data,
      data.record ? data.record.Lineas_de_Venta_HT__r : null
    );
    this.productor = data.record ? data.record.Cuenta_Productor__r : null;

    // ===== NUEVO: INCLUIR INFORMACIÓN DE NOTAS PENDIENTES =====
    if (data.infoNotasCredito) {
      this.infoNotasCredito = data.infoNotasCredito;
      this.mostrarAlertaNotaCredito =
        data.infoNotasCredito.tieneNotasCreditoPendientes;
      this.notasCreditoPendientes = data.infoNotasCredito.detalleNotas || [];
      this.todasLasNC = data.infoNotasCredito.todasLasNC || [];

      console.log(
        "🔍 DEBUG - setData - infoNotasCredito:",
        JSON.stringify(data.infoNotasCredito)
      );
      console.log(
        "🔍 DEBUG - setData - mostrarAlertaNotaCredito:",
        this.mostrarAlertaNotaCredito
      );
      console.log(
        "🔍 DEBUG - setData - notasCreditoPendientes:",
        this.notasCreditoPendientes
      );
    }
  }

  get pageRecordId() {
    if (
      window.location.href.includes("venta-ht/") &&
      !window.location.href.includes("venta-ht/Venta_HT__c/")
    ) {
      return window.location.href.split("venta-ht/")[1].split("/")[0];
    }
    return new URL(window.location.href).searchParams.get("recordId");
  }

  get community() {
    return "Venta";
  }

  get headerClass() {
    return this.showFinanciamientoColumn
      ? "tabla-header con-financiamiento"
      : "tabla-header sin-financiamiento";
  }

  get isPortalObtentor() {
    return basePath.includes("Obtentor");
  }

  get cultivoNombre() {
    const sel = (this.cultivos || []).find((c) => c.value === this.cultivo);
    return sel ? sel.label : "";
  }

  get productorNombre() {
    return this.productor?.Name || "";
  }
  get nombreVenta() {
    return this.data?.record?.Name || "";
  }
  get ventaOriginalId() {
    return this.data?.record?.Venta_Original__c;
  }
  get ventaOriginalName() {
    return this.data?.record?.Venta_Original__r?.Name;
  }
  get mostrarVentaOriginal() {
    return this.esNotaCredito && this.ventaOriginalId;
  }
  get comercioNombre() {
    return this.data?.record?.Nombre_del_comercio__c || "";
  }
  get logoUrl() {
    return icons.semilleros[this.idobtentor];
  }
  get cuit() {
    return (
      this.productor?.PersonDocumentNumber || this.productor?.N_CUIT__c || ""
    );
  }
  get productorMissing() {
    return this.productor == null;
  }
  get estadoVenta() {
    return this.data?.record?.Estado__c || "";
  }
  get estadoVentaClass() {
    const estado = this.estadoVenta.replace(/ /g, "_");
    return `badge-estado-${estado}`;
  }

  // NUEVA PROPIEDAD: Determina si se puede crear Nota de Crédito
  get puedeCrearNotaCredito() {
    const puede =
      this.data &&
      this.data.record &&
      this.data.record.Estado__c === "Facturada" &&
      (this.data.record.Obtentor__r.Id_Obtentor__c == "03" ||
        this.data.record.Obtentor__r.Id_Obtentor__c == "14" ||
        this.data.record.Obtentor__r.Id_Obtentor__c == "85") &&
      !this.infoNotasCredito?.existeNCTotal &&
      !this.infoNotasCredito?.existeNCPPendiente &&
      !this.infoNotasCredito?.existeNCCPendiente;
    console.log(
      "🔍 puedeCrearNotaCredito:",
      puede,
      "infoNotasCredito:",
      JSON.stringify(this.infoNotasCredito)
    );
    return puede;
  }

  get closeLabel() {
    return "Volver al inicio";
  }

  close() {
    const homeUrl = `${basePath}/venta-ht/Venta_HT__c/Default`;
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: homeUrl }
    });
  }

  redirectToNew() {
    const url = `${basePath}/vender`;
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url }
    });
  }

  // MÉTODO: Mostrar confirmación antes de crear NC Total
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

  // MÉTODO CORREGIDO: Crear Nota de Crédito Total
  async crearNotaCreditoTotal() {
    console.log("this.recordId", this.recordId);

    if (!this.recordId) {
      this.onError("No se encontró el ID de la venta");
      return;
    }

    try {
      // Validar que la venta existe y está en estado Facturada
      if (!this.data.record || this.data.record.Estado__c !== "Facturada") {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message:
              "Solo se puede crear Nota de Crédito para ventas en estado Facturada",
            variant: "error"
          })
        );
        return;
      }

      // Navegar a la página de Community con ncCreditoTotal
      const pageUrl = `${basePath}/-nota-credito-total?c__recordId=${this.recordId}`;
      this[NavigationMixin.Navigate]({
        type: "standard__webPage",
        attributes: {
          url: pageUrl
        }
      });
    } catch (error) {
      console.error("Error al abrir el Flow:", error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "No se pudo abrir el Flow: " + error.message,
          variant: "error"
        })
      );
    }
  }

  addRow() {
    const rows = Array.from(
      this.template.querySelectorAll("c-crear-linea-venta")
    );
    if (rows.length && this.productor == null && !this.data.record)
      return this.onError("Debe seleccionar un productor");
    this.addRowInternal(rows);
  }

  saveRow(event) {
    if (this.productor == null && !this.data.record)
      return this.onError("Debe seleccionar un productor");
    event.target.save(this.recordId, this.cultivo, this.productor.Id);
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

  async finalizar() {
    if (this.isChildrenLoading) {
      return this.onError("Espere a que se termine de guardar la línea");
    }

    // Traemos los datos actualizados de la venta antes de validar
    const compraData = await getData({
      ventaId: this.recordId,
      isFirstLoad: true
    });
    this.DataCompra = compraData;

    // Ejecuta canFinish y setea flags de licencia / origen legal
    const guardar = await this.finish();

    // =========================
    // CASO 1: FALTA LICENCIA
    // =========================
    // Cuando NO hay licencia aprobada → mostrar pop de licencia
    //   “Tu compra/venta de HT queda pendiente porque el CUIT no cuenta con la licencia…”
    if (this.haveLicence === false) {
      await this.requestWrap(async () => {
        const data = await finalizarVenta({
          ventaId: this.recordId,
          checkDuplicates: this.recordId != this.lastDuplicateCheckId
        });

        if (data.duplicate) {
          return this.notifyDuplicate();
        }

        // Refresca la venta y las líneas en pantalla
        this.setData(data);
        this.DataCompra = data;
        this.currentModal = data.pendiente
          ? "Pendiente de Facturación"
          : "finalizada";
        await this.getAccount();
        window.sessionStorage.setItem("htPopup_" + this.recordId, "licencia");
        this[NavigationMixin.Navigate]({
          type: "standard__webPage",
          attributes: {
            url: `${basePath}/venta-ht/${this.recordId}`
          }
        });
      });

      return;
    }

    // ==========================================
    // CASO 2: TIENE LICENCIA PERO FALTA ORIGEN
    // ==========================================
    // Cuando hay licencia pero NO hay origen legal → pop de “no encontramos compras o tenencia…”
    if (this.haveOrigenLegal === false && this.haveLicence === true) {
      await this.requestWrap(async () => {
        const data = await finalizarVenta({
          ventaId: this.recordId,
          checkDuplicates: this.recordId != this.lastDuplicateCheckId
        });

        if (data.duplicate) {
          return this.notifyDuplicate();
        }

        // Refresca la venta y las líneas en pantalla
        this.setData(data);
        this.DataCompra = data;
        this.currentModal = data.pendiente
          ? "Pendiente de Facturación"
          : "finalizada";
        await this.getAccount();
        window.sessionStorage.setItem("htPopup_" + this.recordId, "origen");
        this[NavigationMixin.Navigate]({
          type: "standard__webPage",
          attributes: {
            url: `${basePath}/venta-ht/${this.recordId}`
          }
        });
      });

      return;
    }

    // =========================
    // CASO 3: TODO OK
    // =========================
    // Tiene licencia y tiene origen legal → venta normal
    if (guardar === true) {
      await this.requestWrap(async () => {
        const data = await finalizarVenta({
          ventaId: this.recordId,
          checkDuplicates: this.recordId != this.lastDuplicateCheckId
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
          ? "Pendiente de Facturación"
          : "finalizada";
        await this.getAccount();
        this[NavigationMixin.Navigate]({
          type: "standard__webPage",
          attributes: {
            url: `${basePath}/venta-ht/${this.recordId}`
          }
        });
      });
    } else {
      this.isOpen = true;
      // eslint-disable-next-line no-console
      console.log("error no se puede guardar");
    }
  }

  notifyDuplicate() {
    this.currentModal = "duplicate-venta";
    this.lastDuplicateCheckId = this.recordId;
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
            title: "Éxito",
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
            "Debe completar correctamente los campos N° de Comprobante y Fecha de emisión",
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
          message: `El archivo "${file.name}" no es un PDF válido. Solo se permiten archivos PDF.`,
          variant: "error"
        })
      );
      return;
    }

    this.dispatchEvent(
      new ShowToastEvent({
        title: "Éxito",
        message: `Archivo PDF "${file.name}" subido correctamente`,
        variant: "success"
      })
    );
  }

  // ===== Navegación de pasos =====
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
    return "step" + (this.step === 3 ? " active" : "");
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

  handleStepClick(event) {
    const clickedStep = Number(event.currentTarget.dataset.step);
    if (clickedStep <= this.step) this.step = clickedStep;
  }

  cultivoSelected(event) {
    this.cultivo = event.detail.value;
    if (this.cultivo) this.step = 2;
  }

  productorSelected(event) {
    // Portal (Experience): suele venir en event.detail.selection o event.detail.value
    // Interno: algunos lookups custom exponen getSelection()
    let selection = [];
    if (event?.detail && (event.detail.selection || event.detail.value)) {
      selection = event.detail.selection || event.detail.value;
    } else if (event?.target?.getSelection) {
      selection = event.target.getSelection();
    }

    const selArr = Array.isArray(selection)
      ? selection
      : selection
        ? [selection]
        : [];
    const first = selArr[0];
    this.productor = first?.record || first || null;

    if (this.productor) {
      this.step = 3;
      this.getProductos();
    }
  }

  semilleroSelected(event) {
    this.semillero = event.detail;
    this.showResumen = true;
  }

  semilleroSelectedEjecuto(event) {
    this.semillero = event.detail;
    this.getProductos();
    this.step = 3;
    this.showResumen = true;
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
    this.step = 2;
  }

  handleTipoHtChange(event) {
    const { isFutura } = event.detail;
    this.Futura = event.detail.isFutura;
    //this.showFinanciamientoColumn = isFutura && this.cultivoNombre === 'SOJA';
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
            title: "Éxito",
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
    if (this.Futura == true) {
      let poseeLicencia = false;
      var variedades = [];
      if (this.DataCompra.semilleroData?.licencia?.Id) {
        poseeLicencia = true;
      }

      console.log("poseeLicencia:", JSON.stringify(this.DataCompra));

      this.DataCompra.record.Lineas_de_Venta_HT__r.forEach((element) => {
        variedades.push(element.Producto__r.Variedad2__c);
      });

      console.log(variedades);

      try {
        const res = await canFinish({
          semillero: this.DataCompra.semilleroData.semillero,
          CuentaProductor: this.DataCompra.record.Cuenta_Productor__r.Id,
          tieneLicencia: poseeLicencia,
          Variedades: variedades
        });

        this.haveLicence = res.TieneLicencia;
        this.haveOrigenLegal = res.origenLegal;

        console.log("semillero:", JSON.stringify(res));
        console.log("origenLegal:", res.origenLegal);
        console.log("TieneLicencia:", res.TieneLicencia);
        console.log("Variedades:", res.Variedades);
        console.log(JSON.stringify(this.DataCompra));

        if (res.origenLegal === true && res.TieneLicencia === true) {
          return true;
        } else return false;
      } catch (error) {
        console.error("Error en canFinish:", error);
        return false;
      }
    } else {
      return true;
    }
  }

  async getAccount() {
    try {
      this.mostrarBoton = await getAccountFromUser();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Error obteniendo cuenta de usuario:", error);
      this.mostrarBoton = false;
    }
  }
  // ===== MÉTODOS PARA NOTAS DE CRÉDITO =====

  // Activar modo Nota de Crédito por Precio
  activarNotaCreditoPrecio() {
    console.log("Activando modo Nota de Crédito por Precio");
    this.modoNotaCreditoPrecio = true;
    this.modoNotaCreditoCantidad = false;
    this.botonProcesarNCVisible = true;
    this.resetearSeleccionNC();
  }

  // Activar modo Nota de Crédito por Cantidad
  activarNotaCreditoCantidad() {
    console.log("Activando modo Nota de Crédito por Cantidad");
    this.modoNotaCreditoCantidad = true;
    this.modoNotaCreditoPrecio = false;
    this.botonProcesarNCVisible = true;
    this.resetearSeleccionNC();
  }

  // Resetear selección
  resetearSeleccionNC() {
    console.log("Reseteando selección de Nota de Crédito");
    this.lineasSeleccionadasNC = [];
    // Enviar evento a los componentes hijos para resetear su estado
    this.template
      .querySelectorAll("c-crear-linea-venta-new")
      .forEach((child) => {
        child.resetearSeleccionNC();
      });
  }

  // Cancelar modo Nota de Crédito
  cancelarNotaCredito() {
    console.log("Cancelando modo Nota de Crédito");
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

  // Manejar cambio de checkbox desde componente hijo
  handleCheckboxChange(event) {
    const lineaId = event.detail.lineaId;
    const isChecked = event.detail.checked;

    console.log(`Checkbox cambiado para línea ${lineaId}: ${isChecked}`);

    if (isChecked) {
      this.lineasSeleccionadasNC.push(lineaId);
    } else {
      this.lineasSeleccionadasNC = this.lineasSeleccionadasNC.filter(
        (id) => id !== lineaId
      );
    }

    console.log("Líneas seleccionadas:", this.lineasSeleccionadasNC);
  }

  // Manejar cambio de precio desde componente hijo
  handlePrecioChange(event) {
    const lineaId = event.detail.lineaId;
    const nuevoPrecio = event.detail.nuevoPrecio;

    console.log(`Cambio de precio para línea ${lineaId}: ${nuevoPrecio}`);
    // Validaciones se hacen en el componente hijo
  }

  // Manejar cambio de cantidad desde componente hijo
  handleCantidadChange(event) {
    const lineaId = event.detail.lineaId;
    const nuevaCantidad = event.detail.nuevaCantidad;

    console.log(`Cambio de cantidad para línea ${lineaId}: ${nuevaCantidad}`);
    // Validaciones se hacen en el componente hijo
  }

  // Procesar Nota de Crédito - VERSIÓN CORREGIDA
  async procesarNotaCreditoParcial() {
    console.log("Procesando Nota de Crédito Parcial");
    console.log(
      "this.lineasSeleccionadasNC",
      JSON.stringify(this.lineasSeleccionadasNC)
    );

    if (this.lineasSeleccionadasNC.length === 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: this.labels.ncNoLinesSelected, // ✅ USAR LABEL
          variant: "error"
        })
      );
      return;
    }

    // ===== NUEVA VALIDACIÓN: VERIFICAR OBSERVACIONES OBLIGATORIAS =====
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
          message: this.labels.ncAllObservacionesRequired, // ✅ USAR LABEL
          variant: "error"
        })
      );
      return;
    }
    // ===== FIN DE VALIDACIÓN =====

    this.isLoading = true;

    try {
      // Obtener datos de todas las líneas seleccionadas
      const lineasConAjustes = [];
      const componentesHijos = this.template.querySelectorAll(
        "c-crear-linea-venta-new3"
      );
      console.log("Número de componentes hijos:", componentesHijos.length);

      for (const componente of componentesHijos) {
        if (this.lineasSeleccionadasNC.includes(componente.record.Id)) {
          const ajuste = componente.obtenerDatosAjusteNC();
          console.log(
            "Ajuste obtenido del componente:",
            JSON.stringify(ajuste)
          );
          if (ajuste && ajuste.lineaId) {
            // Asegurarse de que los valores sean números
            lineasConAjustes.push({
              lineaId: ajuste.lineaId,
              tipoAjuste: ajuste.tipoAjuste,
              valorAnterior: Number(ajuste.valorAnterior),
              valorNuevo: Number(ajuste.valorNuevo),
              observaciones: this.observacionesLineasNC[ajuste.lineaId] // Incluir observaciones
            });
          }
        }
      }

      if (lineasConAjustes.length === 0) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: "No se encontraron datos válidos para procesar",
            variant: "error"
          })
        );
        return;
      }

      console.log(
        "Lineas con ajustes a enviar:",
        JSON.stringify(lineasConAjustes)
      );

      // Determinar qué método Apex llamar según el tipo de ajuste
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
        // ✅ USAR LABEL CON PARÁMETROS
        const mensajeExito = this.labels.ncProcessSuccess
          .replace("{0}", resultado.notaCreditoName)
          .replace("{1}", resultado.lineasCreadas);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Éxito",
            message: mensajeExito,
            variant: "success"
          })
        );

        // Resetear modos sin mostrar toast
        this.resetearModosNC();

        // Navegar a la nueva Nota de Crédito
        /*  if (resultado.notaCreditoId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: resultado.notaCreditoId,
                        objectApiName: 'Venta_HT__c',
                        actionName: 'view'
                    }
                });
            }*/

        // Recargar datos
        await this.recargarDatos();
      }
    } catch (error) {
      console.error("Error al procesar nota de crédito:", error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Error al procesar nota de crédito",
          variant: "error"
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  // AGREGAR nuevo método para manejar cambios en observaciones desde componentes hijos
  handleObservacionesChange(event) {
    const lineaId = event.detail.lineaId;
    const observaciones = event.detail.observaciones;

    console.log(
      `Observaciones cambiadas para línea ${lineaId}:`,
      observaciones
    );

    // Actualizar el objeto de observaciones
    this.observacionesLineasNC = {
      ...this.observacionesLineasNC,
      [lineaId]: observaciones
    };
  }

  // MODIFICAR método recargarDatos para incluir verificación
  async recargarDatos() {
    try {
      const compraData = await getData({
        ventaId: this.recordId,
        isFirstLoad: true
      });
      this.DataCompra = compraData;
      this.setData(compraData);
      await this.verificarNotasCreditoPendientes(); // VERIFICAR NUEVAMENTE
    } catch (error) {
      this.onError(error);
    }
  }

  // AGREGAR este getter para procesar las notas
  get notasProcesadas() {
    if (!this.notasCreditoPendientes) return [];

    return this.notasCreditoPendientes.map((nota) => ({
      id: nota.id,
      label: this.labels.ncViewLabel.replace("{0}", nota.name),
      title: `Ver ${nota.name}`,
      name: nota.name,
      tipo: nota.tipo,
      fecha: nota.fecha
    }));
  }

  get ncRelacionadas() {
    if (!this.todasLasNC || this.todasLasNC.length === 0) return [];
    return this.todasLasNC.map((nc) => ({
      ...nc,
      tipoLabel: this.obtenerTipoNCLabel(nc.tipo),
      estadoClass: (nc.estado || "").replace(/ /g, "_")
    }));
  }

  obtenerTipoNCLabel(tipo) {
    if (tipo === "NC") return "Total";
    if (tipo === "NCC") return "Cantidad";
    if (tipo === "NCP") return "Precio";
    return tipo || "";
  }

  get mostrarNCRelacionadas() {
    return this.todasLasNC && this.todasLasNC.length > 0 && !this.esNotaCredito;
  }
}