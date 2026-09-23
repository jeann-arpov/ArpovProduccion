import { LightningElement, api, track } from "lwc";
import getDataApex from "@salesforce/apex/CrearCompraController.getData";
import finalizarCompra from "@salesforce/apex/CrearCompraController.finalizarCompra";
import anular from "@salesforce/apex/CrearCompraController.anular";
import getSemilleroData from "@salesforce/apex/CrearCompraController.getSemilleroData";
import getProductsData from "@salesforce/apex/CrearCompraController.getProductsData";
import canFinish from "@salesforce/apex/CrearVentaController.canFinish";
import getUserAccountData from "@salesforce/apex/CrearCompraController.getUserAccountData";
import updateTipoPago from "@salesforce/apex/CrearCompraController.updateTipoPago";
import verificarExpedienteEnHTDisponible from "@salesforce/apex/ExpedientesController.verificarExpedienteEnHTDisponible";
import { CompraVentaMixin } from "c/utilsHTNew";
import { NavigationMixin } from "lightning/navigation";
import resourcePortal from "@salesforce/resourceUrl/resourcePortal";
import basePath from "@salesforce/community/basePath";
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

/** Temporal: true = no se muestra el modal de expediente negativo en HT disponible ni se detiene finalizar. */
const OMITIR_MODAL_ALERTA_EXPEDIENTE_NEGATIVO = true;
const FECHA_INICIO_STINE_DEFAULT = "2026-09-21";
const FECHA_FIN_STINE_DEFAULT = "2026-10-31";

export default class CrearCompra2 extends CompraVentaMixin(LightningElement) {
  showFacturaRegaliaEnlistMsg;
  iconCebadaUrl = `${resourcePortal}/resourcePortal/images/prd-cebada.svg`;
  iconSojaHTUrl = `${resourcePortal}/resourcePortal/images/prd-soja.svg`;
  iconTrigoHTUrl = `${resourcePortal}/resourcePortal/images/prd-trigo.svg`;
  iconCondicionesHTUrl = `${resourcePortal}/resourcePortal/images/icon-condiciones.svg`;
  productor;
  showResumen = false;
  semilleroIcono = false;
  showFileUploadModal = false;
  isLoading = false;
  showFinanciamientoColumn = false;
  isModalOpen = false;
  @track DataCompra;
  isOpen = false;
  isOpen2 = false;
  haveLicence;
  haveOrigenLegal;
  @track Blanqueo;
  esFutura = false;
  Futura;
  tipoCompraSeleccionado = null;
  @track _lineasListasFlag = false;
  @track guardandoLineas = false;
  @track finalizandoOperacion = false;
  @track isOpenPaymentModal = false;
  @track modalItems = [];

  // Configuración comunidad Stine
  @api fechaInicioStine;
  @api fechaFinStine;

  tipoPago = null; // 'Contado' | 'Financiado'
  pendingFinalizar = false; // para reintentar
  pendingFinalizarPorExpediente = false;
  shouldMarkRevisarCompra = false;

  // Banderas guardado Stine Modal
  tipoPagoStineSeleccionado = null;
  @track entidadBancariaStine = null;
  @track plazoStine = null;
  @track monedaStine = null;
  @track tasaStine = null;

  htFuturaPromoMessage = null;
  htFuturaPromoVariant = "success";
  htFuturaPromoPreviouslyQualified = false;
  htFuturaPromoCelebrationShown = false;

  get bloqueCompraClass() {
    return this.showResumen ? "oculto" : "visible";
  }

  get bloqueResumenClass() {
    return this.showResumen ? "visible" : "oculto";
  }

  get headerClass() {
    return this.showFinanciamientoColumn
      ? "tabla-header con-financiamiento"
      : "tabla-header sin-financiamiento";
  }
  get cultivoNombre() {
    const seleccionado = (this.cultivos || []).find(
      (c) => c.value === this.cultivo
    );
    return seleccionado ? seleccionado.label : "";
  }

  get esVentaHtFutura() {
    const esHT = this.tipoVenta && this.tipoVenta.toUpperCase() === "HT";
    const esFutura = this.campana && this.campana.toUpperCase().includes("FUTURA");
    return esHT && esFutura;
  }

  get esMarcaStine() {
    if (this.marca && this.marca.toUpperCase() === "STINE") return true;
    const semilleroSeleccionado = this.semilleros?.find(s => s.value === this.semillero);
    return semilleroSeleccionado?.label?.toUpperCase().includes("STINE") || false;
  }

  get fechaInicioEfectiva() {
        // 1. Prioriza lo configurado en la Comunidad
        if (this.fechaInicioStine) return this.fechaInicioStine;
        // 2. Si es undefined (venga de donde venga el usuario), usa el respaldo guardado en sesión
        const guardado = sessionStorage.getItem('stine_fechaInicio');
        if (guardado) return guardado;
        // 3. Si no hay nada, usa la constante por defecto
        return FECHA_INICIO_STINE_DEFAULT;
    }

    get fechaFinEfectiva() {
        if (this.fechaFinStine) return this.fechaFinStine;
        const guardado = sessionStorage.getItem('stine_fechaFin');
        if (guardado) return guardado;
        return FECHA_FIN_STINE_DEFAULT;
    }

   estaEnRangoFechasStine() {
        const inicio = this.fechaInicioEfectiva;
        const fin = this.fechaFinEfectiva;

        // Si por alguna razón no hay fechas, no bloquea ni muestra modal
        if (!inicio || !fin) {
            return false;
        }

        // Si la Comunidad envió valores válidos en esta vista, actualizamos el almacenamiento local
        if (this.fechaInicioStine) sessionStorage.setItem('stine_fechaInicio', this.fechaInicioStine);
        if (this.fechaFinStine) sessionStorage.setItem('stine_fechaFin', this.fechaFinStine);

        // Obtenemos la fecha de hoy local en formato YYYY-MM-DD
        const hoy = new Date();
        const year = hoy.getFullYear();
        const month = String(hoy.getMonth() + 1).padStart(2, '0');
        const day = String(hoy.getDate()).padStart(2, '0');
        const hoyStr = `${year}-${month}-${day}`;

        return hoyStr >= inicio && hoyStr <= fin;
    }

  async evaluarEsStineFutura() {
    console.log("--- [DEBUG] Ejecutando evaluarEsStineFutura ---");

    if (!await this.estaEnRangoFechasStine()) {
      console.log("--- [DEBUG] Fuera de rango de fechas configurado para Stine. Se omite modal y persistencia. ---");
      return false;
    }

    const lineas = [
      ...(this.DataCompra?.record?.Lineas_de_Compra_HT__r || []),
      ...(this.data?.record?.Lineas_de_Compra_HT__r || []),
      ...(this.items || []).map(i => i.record || i)
    ];
    console.log("Líneas recopiladas:", JSON.parse(JSON.stringify(lineas)));

    let tieneStineFuturaEnLineas = false;

    for (const rec of lineas) {
      const obtentor = rec.Producto__r?.Variedad2__r?.Obtentor_Comercializa__r?.Name || "";
      const tipoCompra = rec.Tipo_de_Compra__c || rec.Producto__r?.Tipo_de_Compra__c || "";

      console.log(`Analizando línea -> Obtentor: "${obtentor}", TipoCompra: "${tipoCompra}"`);

      const esObtentorStineExacto = obtentor === "M.S. TECHNOLOGIES ARGENTINA S.R.L.";
      const esTipoFutura = tipoCompra === "Futura" || this.Futura;

      if (esObtentorStineExacto && esTipoFutura) {
        tieneStineFuturaEnLineas = true;
        break;
      }
    }

    console.log("--- [DEBUG] Resultado final evaluarEsStineFutura:", tieneStineFuturaEnLineas);
    return tieneStineFuturaEnLineas;
  }

  async connectedCallback() {
    try {
      const data = await getUserAccountData();
      this.productor = {
        Name: data?.productorNombre,
        N_CUIT__c: data?.cuit
      };

      if (this.pageRecordId) {
        this.step = 3;
        this.showResumen = true;
        this.isLoading = true;

        try {
          const compraData = await getDataApex({
            compraId: this.pageRecordId,
            isFirstLoad: true
          });
          this.DataCompra = compraData;
          this.setData(compraData);
          await this.finish();
          await this.validarExpedienteDisponible(false);
          setTimeout(() => {
            this.syncPromoQualificationState();
            this.refreshAllLinePromoPrices();
            this.notifyLineSaveStateChanged();
          }, 250);
          if (typeof window !== "undefined") {
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
          }
        } catch (e) {
          console.error("Error cargando compra desde Apex", e);
        } finally {
          this.isLoading = false;
        }
      }
    } catch (error) {
      console.error("Error obteniendo la cuenta del usuario:", error);
    }
  }

  handleOpenModal(event) {
    this.isModalOpen = true;
  }

  openModal(event) {
    this.isModalOpen = true;
  }

  async closeModal() {
    const debeContinuarFinalizar =
      this.currentModal === "expediente-disponible-alert" &&
      this.pendingFinalizarPorExpediente;

    this.isModalOpen = false;
    this.isOpen = false;
    this.isOpen2 = false;
    this.currentModal = null;

    if (debeContinuarFinalizar) {
      this.shouldMarkRevisarCompra = true;
      this.pendingFinalizarPorExpediente = false;
      await this.finalizar({ mostrarModalExpediente: false });
    }
  }

  // ====== DATA ======
  getData(isFirstLoad) {
    return getDataApex({ compraId: this.recordId, isFirstLoad });
  }

  handleSemilleroIconReady(event) {
    this.semilleroIcono = event.detail;
    if (event.detail == null) {
      this.step = 3;
    }
  }

  setData(data) {
    const lineas = data?.record?.Lineas_de_Compra_HT__r || [];
    this.setDataAndItems(data, lineas);

    if (!this.tipoCompraSeleccionado && lineas.length > 0 && data.products) {
      const ultimaLinea = lineas[lineas.length - 1];
      const pbe = data.products.find(
        (p) => p.Id === ultimaLinea.Id_Producto_de_Lista_de_Precio__c
      );
      if (pbe?.Product2?.Tipo_de_Compra__c) {
        this.tipoCompraSeleccionado = pbe.Product2.Tipo_de_Compra__c;
        this.Futura = this.tipoCompraSeleccionado === "Futura";
      }
    }
  }

  get pageRecordId() {
    if (typeof window === "undefined") return null;
    try {
      const href = window.location.href;
      const url = new URL(href);
      let recordIdValue = url.searchParams.get("recordId");

      if (
        !recordIdValue &&
        href.includes("compra-ht/") &&
        !href.includes("compra-ht/Compra_HT__c/")
      ) {
        recordIdValue = href.split("compra-ht/")[1]?.split("/")[0] || null;
      }

      this.recordId = recordIdValue || null;
      return this.recordId;
    } catch (e) {
      this.recordId = null;
      return null;
    }
  }

  get parametroCultivo() {
    return new URL(window.location.href).searchParams.get("cultivoId");
  }

  get community() {
    return "Compra";
  }

  // ====== LÍNEAS ======
  addRow(event) {
    this.addRowInternal(
      Array.from(this.template.querySelectorAll("c-crear-linea-compra"))
    );
  }

  saveRow(event) {
    event.target.save(this.recordId, this.cultivo);
  }

  get mostrarContinuar() {
    if (!this.puedeEditar || this.guardandoLineas) {
      return false;
    }
    this._lineasListasFlag;
    return this.tieneLineasPendientesDeGuardar;
  }

  get mostrarFinalizarCompra() {
    return (
      this.puedeFinalizar &&
      !this.guardandoLineas &&
      !this.tieneLineasPendientesDeGuardar
    );
  }

  get tieneLineasPendientesDeGuardar() {
    if (this.guardandoLineas) {
      return true;
    }
    const children = this.template.querySelectorAll("c-crear-linea-compra-new");
    for (const child of children) {
      const rec = child.record;
      if (!rec?.Producto__c || !rec?.Cantidad__c) continue;
      if (!rec.Id) return true;
      if (child.hasUnsavedChanges?.()) return true;
    }
    return false;
  }

  async continuar() {
    this.guardandoLineas = true;
    try {
      this.refreshAllLinePromoPrices();
      await this.saveAllPendingLines();
      await new Promise((resolve) => setTimeout(resolve, 200));
      this.refreshAllLinePromoPrices();
      this.notifyLineSaveStateChanged();
    } catch (e) {
      this.onError("Error al guardar las líneas: " + (e.message || e));
    } finally {
      this.guardandoLineas = false;
    }
  }

  notifyLineSaveStateChanged() {
    this._lineasListasFlag = !this._lineasListasFlag;
  }

  handleCantidadChange() {
    this._lineasListasFlag = !this._lineasListasFlag;
    Promise.resolve().then(() => {
      this.refreshAllLinePromoPrices();
      this.notifyLineSaveStateChanged();
    });
  }

  computeHtFuturaPromoCantidadTotal() {
    if (
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
    if (!this.showResumen) {
      return;
    }
    const total = this.computeHtFuturaPromoCantidadTotal();
    this.template
      .querySelectorAll("c-crear-linea-compra-new")
      .forEach((line) => {
        line.refreshPromoPrice?.(total);
      });
  }

  get hayLineasListas() {
    const children = this.template.querySelectorAll("c-crear-linea-compra-new");
    for (const child of children) {
      const rec = child.record;
      if (rec && rec.Producto__c && rec.Cantidad__c > 0) return true;
    }
    return false;
  }

  get finalizarDeshabilitado() {
    return this.isLoading || this.finalizandoOperacion;
  }

  async saveAllPendingLines() {
    this._savingAllPending = true;
    try {
      const children = Array.from(
        this.template.querySelectorAll("c-crear-linea-compra-new")
      );
      for (const child of children) {
        const rec = child.record;
        if (!rec?.Producto__c || !rec?.Cantidad__c) {
          continue;
        }
        if (!rec.Id || child.hasUnsavedChanges?.()) {
          await child.save(this.recordId, this.cultivo);
          this.assignSavedLineToChild(child);
        }
      }
      this.finalizePendingBatchSave();
    } finally {
      this._savingAllPending = false;
    }
  }

  async finalizar(options = {}) {
    const { mostrarModalExpediente = true } = options;
    const marcarRevisarCompra = this.shouldMarkRevisarCompra === true;
    this.shouldMarkRevisarCompra = false;
    this.finalizandoOperacion = true;

    try {
      // Evaluamos directamente la función de Stine aquí
      const esStineFutura = await this.evaluarEsStineFutura();

      if (esStineFutura && !this.tipoPagoStineSeleccionado) {
        try {
          this.isLoading = true;
          await this.saveAllPendingLines();
        } catch (e) {
          this.isLoading = false;
          return this.onError("Error al guardar las líneas: " + (e.message || e));
        } finally {
          this.isLoading = false;
        }

        this.prepararModalItems();

        this.pendingFinalizar = true;
        this.currentModal = "forma-pago-stine";
        return;
      }

      // Si no es Stine Futura o está fuera del rango de fechas, reseteamos las variables
      if (!esStineFutura) {
        this.entidadBancariaStine = null;
        this.plazoStine = null;
        this.monedaStine = null;
        this.tasaStine = null;
      }

      try {
        this.isLoading = true;
        await this.saveAllPendingLines();
      } catch (e) {
        this.isLoading = false;
        return this.onError("Error al guardar las líneas: " + (e.message || e));
      }
      this.isLoading = false;

      // ===== Gate Tipo de Pago =====
      if (this.requiresTipoPago() && !this.tipoPago) {
        this.pendingFinalizar = true;
        this.currentModal = "tipo-pago";
        return;
      }

      if (this.isChildrenLoading) {
        return this.onError("Espere a que se termine de guardar la línea");
      }

      // Traemos los datos actualizados de la compra antes de validar
      const compraData = await getDataApex({
        compraId: this.recordId,
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

      // Ejecuta canFinish y setea flags de licencia / origen legal
      const guardar = await this.finish();

      if (guardar === false) {
        if (this.haveLicence === false || (this.haveLicence === false && this.haveOrigenLegal === false)) {
          await this.requestWrap(async () => {
            const data = await finalizarCompra({
              compraId: this.recordId,
              checkDuplicates: this.recordId != this.lastDuplicateCheckId,
              origen: this.haveOrigenLegal,
              blanqueo: this.Blanqueo === true,
              marcarRevisarCompra,
              entidadBancaria: this.entidadBancariaStine,
              plazo: this.plazoStine,
              moneda: this.monedaStine,
              tasa: this.tasaStine
            });

            if (data.duplicate) {
              return this.notifyDuplicate();
            }

            this.setData(data);
            this.DataCompra = data;
            this.currentModal = data.pendiente
              ? "Pendiente de Facturación"
              : "finalizada";
            window.sessionStorage.setItem(
              "htPopup_" + this.recordId,
              "licencia"
            );
            this.isOpen2 = true;
          });

          return;
        }

        if (this.haveOrigenLegal === false && this.haveLicence === true) {
          await this.requestWrap(async () => {
            const data = await finalizarCompra({
              compraId: this.recordId,
              checkDuplicates: this.recordId != this.lastDuplicateCheckId,
              origen: this.haveOrigenLegal,
              blanqueo: this.Blanqueo === true,
              marcarRevisarCompra,
              entidadBancaria: this.entidadBancariaStine,
              plazo: this.plazoStine,
              moneda: this.monedaStine,
              tasa: this.tasaStine
            });

            if (data.duplicate) {
              return this.notifyDuplicate();
            }

            this.setData(data);
            this.DataCompra = data;
            this.currentModal = data.pendiente
              ? "Pendiente de Facturación"
              : "finalizada";
            window.sessionStorage.setItem("htPopup_" + this.recordId, "origen");
            this.isOpen = true;
          });

          return;
        }
      } else if (guardar === true) {
        await this.requestWrap(async () => {
          const data = await finalizarCompra({
            compraId: this.recordId,
            checkDuplicates: this.recordId != this.lastDuplicateCheckId,
            origen: this.haveOrigenLegal,
            blanqueo: this.Blanqueo === true,
            marcarRevisarCompra,
            entidadBancaria: this.entidadBancariaStine,
            plazo: this.plazoStine,
            moneda: this.monedaStine,
            tasa: this.tasaStine
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
          this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
              url: `${basePath}/comprahtlistproductor`
            }
          });
        });
      }
    } finally {
      this.finalizandoOperacion = false;
    }
  }

  prepararModalItems() {
    const lineasDOM = Array.from(
      this.template.querySelectorAll("c-crear-linea-compra-new")
    );

    if (lineasDOM.length > 0) {
      this.modalItems = lineasDOM.map((child, index) => {
        const rec = child.record || {};
        const productoId = rec.Producto__c;
        let variedadNombre = "";

        if (productoId && this.variedades) {
          const prodEncontrado = this.variedades.find(
            (v) => v.record?.Product2Id === productoId || v.value === productoId
          );
          if (prodEncontrado && prodEncontrado.label) {
            variedadNombre = prodEncontrado.label;
          }
        }
        if (!variedadNombre && rec.Producto__r?.Name) {
          variedadNombre = rec.Producto__r.Name;
        }
        if (!variedadNombre) {
          variedadNombre = "Variedad " + (index + 1);
        }

        const cantidad = parseFloat(rec.Cantidad__c) || 0;
        const precio =
          parseFloat(rec.Precio_Unitario__c) ||
          parseFloat(rec.Precio_de_Lista__c) ||
          0;
        const totalCalculado = precio * cantidad;

        return {
          id: rec.Id || `linea-${index}`,
          variedad: variedadNombre,
          ht: cantidad,
          precioUnitario: this.formatCurrency(precio),
          total: this.formatCurrency(totalCalculado)
        };
      });
    } else if (this.data?.record?.Lineas_de_Compra_HT__r) {
      this.modalItems = this.data.record.Lineas_de_Compra_HT__r.map(
        (item, index) => {
          const precio =
            parseFloat(item.Precio_Unitario__c) ||
            parseFloat(item.Precio_de_Lista__c) ||
            0;
          const cantidad = parseFloat(item.Cantidad__c) || 0;
          const totalCalculado = precio * cantidad;

          return {
            id: item.Id || `linea-${index}`,
            variedad: item.Producto__r?.Name || "Variedad " + (index + 1),
            ht: cantidad,
            precioUnitario: this.formatCurrency(precio),
            total: this.formatCurrency(totalCalculado)
          };
        }
      );
    } else {
      this.modalItems = [];
    }
  }

  async handleConfirmPaymentStine(event) {
    const { formaPago, entidadBancaria, plazo, moneda, tasa } = event.detail;

    this.tipoPagoStineSeleccionado = formaPago;
    this.tipoPago = formaPago;

    this.entidadBancariaStine = formaPago === "Financiado" ? entidadBancaria : null;
    this.plazoStine = formaPago === "Financiado" ? plazo : null;
    this.monedaStine = formaPago === "Financiado" ? moneda : null;
    this.tasaStine = formaPago === "Financiado" ? tasa : null;

    const activeRecordId = this.recordId || this.pageRecordId;

    this.isLoading = true;
    try {
      await updateTipoPago({
        compraId: activeRecordId,
        tipoPago: formaPago,
        entidadBancaria: this.entidadBancariaStine,
        plazo: this.plazoStine,
        moneda: this.monedaStine,
        tasa: this.tasaStine
      });
    } catch (e) {
      console.error("Error detallado en handleConfirmPaymentStine:", e);
      const errorMsg = e.body?.message || e.message || (typeof e === 'object' ? JSON.stringify(e) : e);
      this.onError("Error al guardar datos de pago: " + errorMsg);
      this.isLoading = false;
      return;
    }

    this.isLoading = false;
    this.currentModal = null;
    this.pendingFinalizar = false;

    this.finalizar();
  }

  handleClosePaymentStine() {
    this.currentModal = null;
    this.pendingFinalizar = false;
  }

  formatCurrency(val) {
    if (isNaN(val)) return "0,00";
    return parseFloat(val).toLocaleString("es-AR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  }

  notifyDuplicate() {
    this.currentModal = "duplicate-compra";
    this.lastDuplicateCheckId = this.recordId;
  }

  async anular(event) {
    await this.requestWrap(async () => {
      const data = await anular({ compraId: this.recordId });
      this.setData(data);
      this.currentModal = null;
      this.redirectPendientesFacturacion();
    });
  }

  // ====== DATOS COMPLEMENTARIOS ======
  getSemilleroData() {
    return getSemilleroData({ obtentorId: this.semillero });
  }

  async getProductos() {
    await this.requestWrap(async () => {
      const products = await getProductsData({ cultivoId: this.cultivo });
      this.updateVariedades(products);
    });
    this.step = 2;
  }

  // ====== STEPS ======
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
    if (clickedStep <= this.step) {
      this.step = clickedStep;
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

  async handleSelectCultivo(event) {
    const cultivoId = event.currentTarget?.dataset?.id;
    if (!cultivoId) return;
    this.cultivo = cultivoId;
    this.cultivoSeleccionadoId = cultivoId;
    await this.getProductos();
  }

  async semilleroSelectedEjecuto(event) {
    this.semillero = event.detail;
    await this.requestWrap(async () => {
      this.semilleroData = await this.getSemilleroData();
    });
    this.showResumen = true;
    setTimeout(() => {
      this.syncPromoQualificationState();
      this.refreshAllLinePromoPrices();
    }, 250);
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
          "Se trata de las HT que son precertificables dentro de los plazos del programa y la conversión a toneladas se produce a partir de la entrega de grano."
      },
      {
        value: "Disponible",
        label: "HT Disponible",
        description:
          "Se trata de las HT que acreditan inmediatamente toneladas. Sólo se pueden adquirir antes de la entrega de grano. No son precertificables."
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
    this.step = 3;
  }

  get variedades() {
    const todas = this.variedadesByObtentor?.[this.semillero] || [];
    if (!this.tipoCompraSeleccionado) return todas;
    return todas.filter(
      (v) =>
        v.record?.Product2?.Tipo_de_Compra__c === this.tipoCompraSeleccionado
    );
  }

  openFileUpload() {
    this.showFileUploadModal = true;
  }

  closeFileUpload() {
    this.showFileUploadModal = false;
  }

  get acceptedFormats() {
    return [".pdf"];
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

    this.closeFileUpload();
  }

  handleTipoHtChange(event) {
    const { isFutura } = event.detail;
    this.Futura = event.detail.isFutura;
    this.showFinanciamientoColumn = isFutura && this.cultivoNombre === "SOJA";
    this.syncPromoQualificationState();
    Promise.resolve().then(() => {
      this.refreshAllLinePromoPrices();
      this.notifyLineSaveStateChanged();
    });
  }

  handlePromoLineChange(event) {
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
    cancelHtFuturaPromoEval(this);
  }

  collectPromoLineData() {
    const rows = Array.from(
      this.template.querySelectorAll("c-crear-linea-compra-new")
    );
    if (rows.length) {
      return rows.map((row) => row.getPromoLineData()).filter(Boolean);
    }

    const records = this.data?.record?.Lineas_de_Compra_HT__r || [];
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

  async finish() {
    let poseeLicencia = false;
    const variedades = [];

    if (!this.DataCompra || !this.DataCompra.record) {
      return false;
    }

    if (this.DataCompra.semilleroData?.licencia?.Id) {
      poseeLicencia = true;
    }

    const lineasCompra = this.DataCompra.record.Lineas_de_Compra_HT__r || [];
    lineasCompra.forEach((element) => {
      if (element.Producto__r?.Variedad2__c) {
        variedades.push(element.Producto__r.Variedad2__c);
      }
    });

    try {
      const res = await canFinish({
        semillero: this.DataCompra.semilleroData?.semillero || {},
        CuentaProductor: this.DataCompra.record.Cuenta_Productor__r?.Id,
        tieneLicencia: poseeLicencia,
        Variedades: variedades,
        tipoCompra: this.tipoCompraSeleccionado,
        cultivoId: this.DataCompra.record.Cultivo__c
      });

      this.haveLicence = res.TieneLicencia;
      this.haveOrigenLegal = res.origenLegal;
      this.Blanqueo = res.Blanqueo === true;

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
        "Error crítico al ejecutar validaciones (canFinish):",
        error
      );
      return false;
    }
  }

  get productorNombre() {
    return this.productor?.Name || "";
  }
  get logoUrl() {
    return icons.semilleros[this.idobtentor];
  }

  get cuit() {
    return (
      this.productor?.PersonDocumentNumber || this.productor?.N_CUIT__c || ""
    );
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
    this.entidadBancariaStine = null;
    this.plazoStine = null;
    this.monedaStine = null;
    this.tasaStine = null;

    await this.requestWrap(async () => {
      const data = await updateTipoPago({
        compraId: this.recordId,
        tipoPago: value,
        entidadBancaria: null,
        plazo: null,
        moneda: null,
        tasa: null
      });
      this.setData(data);
      this.DataCompra = data;
    });

    this.currentModal = null;

    if (this.pendingFinalizar) {
      this.pendingFinalizar = false;
      await this.finalizar();
    }
  }

  async validarExpedienteDisponible(mostrarModalSiTieneExpediente) {
    if (!this.recordId) {
      return false;
    }
    if (OMITIR_MODAL_ALERTA_EXPEDIENTE_NEGATIVO) {
      return false;
    }
    try {
      const result = await verificarExpedienteEnHTDisponible({
        compraVentaId: this.recordId,
        tipoOperacion: "compra"
      });
      const tieneExpediente = Boolean(result?.tieneExpediente);
      if (tieneExpediente && mostrarModalSiTieneExpediente) {
        this.currentModal = "expediente-disponible-alert";
        return true;
      }
      return false;
    } catch (error) {
      console.error(
        "Error validando expediente en HT disponible (compra):",
        error
      );
      return false;
    }
  }
}