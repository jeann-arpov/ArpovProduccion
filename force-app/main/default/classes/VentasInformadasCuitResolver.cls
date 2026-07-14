/**
 * Resuelve Originante / Destinatario por CUIT en Ventas Informadas.
 * Cuando un mismo CUIT corresponde a varias cuentas Obtentor (marcas),
 * prioriza Obtentor_Comercializa__c del maestro de producto (Variedad).
 */
public without sharing class VentasInformadasCuitResolver {

  /**
   * @param cuit CUIT normalizado (solo dígitos).
   * @param obtentorComercializaId Account Id desde Variedad__c.Obtentor_Comercializa__c.
   * @param candidatos Cuentas con ese CUIT (sin sucursales salvo excepciones del query).
   */
  @TestVisible
  public static Account resolveCuentaPorCuit(
    String cuit,
    Id obtentorComercializaId,
    List<Account> candidatos
  ) {
    return resolveCuentaPorCuit(cuit, obtentorComercializaId, candidatos, null);
  }

  @TestVisible
  public static Account resolveCuentaPorCuit(
    String cuit,
    Id obtentorComercializaId,
    List<Account> candidatos,
    Map<Id, Account> obtComById
  ) {
    if (obtentorComercializaId != null) {
      Account obtCom = resolverObtentorComercializaPorCuit(
        cuit,
        obtentorComercializaId,
        candidatos,
        obtComById
      );
      if (obtCom != null) {
        return obtCom;
      }
    }

    if (candidatos == null || candidatos.isEmpty()) {
      return null;
    }

    for (Account acc : candidatos) {
      if (acc.RecordType != null && acc.RecordType.DeveloperName != 'Proveedor') {
        return acc;
      }
    }
    return candidatos[0];
  }

  /**
   * Prioriza Obtentor_Comercializa__c del maestro de variedad cuando el CUIT coincide.
   * Cubre marcas hijas (ParentId != null) que no entran en la query por CUIT.
   */
  @TestVisible
  private static Account resolverObtentorComercializaPorCuit(
    String cuit,
    Id obtentorComercializaId,
    List<Account> candidatos,
    Map<Id, Account> obtComById
  ) {
    if (obtentorComercializaId == null) {
      return null;
    }

    if (candidatos != null) {
      for (Account acc : candidatos) {
        if (acc.Id == obtentorComercializaId) {
          return acc;
        }
      }
    }

    Account cached = obtComById != null ? obtComById.get(obtentorComercializaId) : null;
    if (cached == null && obtComById == null) {
      List<Account> obtCom = [
        SELECT Id, N_CUIT__c, Type, Name, RecordType.DeveloperName
        FROM Account
        WHERE Id = :obtentorComercializaId
        LIMIT 1
      ];
      cached = obtCom.isEmpty() ? null : obtCom[0];
    }

    if (
      cached != null &&
      CrearVentaInformadaLWCController.limpiarCuit(cached.N_CUIT__c) ==
      CrearVentaInformadaLWCController.limpiarCuit(cuit)
    ) {
      return cached;
    }
    return null;
  }

  @TestVisible
  public static Map<String, List<Account>> agruparCuentasPorCuit(List<Account> cuentas) {
    Map<String, List<Account>> porCuit = new Map<String, List<Account>>();
    if (cuentas == null) {
      return porCuit;
    }
    for (Account acc : cuentas) {
      if (acc == null || String.isBlank(acc.N_CUIT__c)) {
        continue;
      }
      String key = CrearVentaInformadaLWCController.limpiarCuit(acc.N_CUIT__c);
      if (String.isBlank(key)) {
        continue;
      }
      if (!porCuit.containsKey(key)) {
        porCuit.put(key, new List<Account>());
      }
      porCuit.get(key).add(acc);
    }
    return porCuit;
  }

  /**
   * Busca cuentas por CUIT aceptando formato con/sin guiones (planilla → solo dígitos).
   */
  @TestVisible
  public static Map<String, List<Account>> queryCuentasPorCuitsNormalizados(Set<String> cuits) {
    Set<String> normalizados = new Set<String>();
    if (cuits != null) {
      for (String cuit : cuits) {
        String limpio = CrearVentaInformadaLWCController.limpiarCuit(cuit);
        if (String.isNotBlank(limpio)) {
          normalizados.add(limpio);
        }
      }
    }
    if (normalizados.isEmpty()) {
      return new Map<String, List<Account>>();
    }

    List<Account> cuentas = [
      SELECT Id, N_CUIT__c, Type, Name, RecordType.DeveloperName
      FROM Account
      WHERE (
        N_CUIT__c IN :normalizados
        OR N_CUIT__c IN :cuits
      )
      AND (
        (N_CUIT__c IN ('30569723023', '30715468294') AND Type = 'Obtentor')
        OR ParentId = NULL
      )
    ];

    Set<String> encontrados = new Set<String>();
    for (Account acc : cuentas) {
      String key = CrearVentaInformadaLWCController.limpiarCuit(acc.N_CUIT__c);
      if (String.isNotBlank(key)) {
        encontrados.add(key);
      }
    }

    Set<String> missing = new Set<String>();
    for (String cuit : normalizados) {
      if (!encontrados.contains(cuit)) {
        missing.add(cuit);
      }
    }
    if (!missing.isEmpty()) {
      resolverCuentasCuitFaltantes(cuentas, missing, encontrados);
    }

    return agruparCuentasPorCuit(cuentas);
  }

  /** Segunda pasada acotada: variantes con guiones y LIKE por CUIT (evita scan de 50k cuentas). */
  @TestVisible
  private static void resolverCuentasCuitFaltantes(
    List<Account> cuentas,
    Set<String> missing,
    Set<String> encontrados
  ) {
    if (missing == null || missing.isEmpty()) {
      return;
    }

    Set<String> variantes = new Set<String>();
    for (String cuit : missing) {
      variantes.addAll(variantesCuitParaBusqueda(cuit));
    }
    for (List<String> chunk : chunkStrings(new List<String>(variantes), 200)) {
      Set<String> chunkSet = new Set<String>(chunk);
      for (Account acc : [
        SELECT Id, N_CUIT__c, Type, Name, RecordType.DeveloperName
        FROM Account
        WHERE N_CUIT__c IN :chunkSet
        AND (
          (N_CUIT__c IN ('30569723023', '30715468294') AND Type = 'Obtentor')
          OR ParentId = NULL
        )
      ]) {
        String key = CrearVentaInformadaLWCController.limpiarCuit(acc.N_CUIT__c);
        if (String.isNotBlank(key) && missing.contains(key)) {
          cuentas.add(acc);
          encontrados.add(key);
        }
      }
    }

    Set<String> stillMissing = new Set<String>();
    for (String cuit : missing) {
      if (!encontrados.contains(cuit)) {
        stillMissing.add(cuit);
      }
    }
    for (String cuit : stillMissing) {
      if (stillMissing.size() > 50) {
        break;
      }
      String pattern = '%' + cuit + '%';
      for (Account acc : [
        SELECT Id, N_CUIT__c, Type, Name, RecordType.DeveloperName
        FROM Account
        WHERE N_CUIT__c LIKE :pattern
        AND ParentId = NULL
        LIMIT 15
      ]) {
        String key = CrearVentaInformadaLWCController.limpiarCuit(acc.N_CUIT__c);
        if (stillMissing.contains(key)) {
          cuentas.add(acc);
          encontrados.add(key);
        }
      }
    }
  }

  @TestVisible
  private static Set<String> variantesCuitParaBusqueda(String cuitLimpio) {
    Set<String> out = new Set<String>();
    if (String.isBlank(cuitLimpio)) {
      return out;
    }
    out.add(cuitLimpio);
    if (cuitLimpio.length() == 11) {
      out.add(
        cuitLimpio.substring(0, 2) + '-' +
        cuitLimpio.substring(2, 10) + '-' +
        cuitLimpio.substring(10)
      );
    }
    return out;
  }

  @TestVisible
  private static List<List<String>> chunkStrings(List<String> values, Integer size) {
    List<List<String>> chunks = new List<List<String>>();
    if (values == null || values.isEmpty() || size == null || size < 1) {
      return chunks;
    }
    for (Integer i = 0; i < values.size(); i += size) {
      List<String> chunk = new List<String>();
      for (Integer j = i; j < Math.min(i + size, values.size()); j++) {
        chunk.add(values[j]);
      }
      chunks.add(chunk);
    }
    return chunks;
  }

  /**
   * Cache de cuentas por CUIT para import masivo / trigger (evita 1 SOQL por fila).
   */
  public class CuitResolverCache {
    public Map<String, List<Account>> cuentasPorCuit { get; private set; }
    public Map<Id, Account> accountsById { get; private set; }

    private CuitResolverCache() {
      cuentasPorCuit = new Map<String, List<Account>>();
      accountsById = new Map<Id, Account>();
    }

    public void indexAccountsFromPorCuit() {
      for (List<Account> lista : cuentasPorCuit.values()) {
        for (Account acc : lista) {
          accountsById.put(acc.Id, acc);
        }
      }
    }

    public void mergeCuentasPorCuit(Map<String, List<Account>> otras) {
      if (otras == null || otras.isEmpty()) {
        return;
      }
      for (String cuit : otras.keySet()) {
        if (!cuentasPorCuit.containsKey(cuit)) {
          cuentasPorCuit.put(cuit, new List<Account>());
        }
        for (Account acc : otras.get(cuit)) {
          Boolean exists = false;
          for (Account existing : cuentasPorCuit.get(cuit)) {
            if (existing.Id == acc.Id) {
              exists = true;
              break;
            }
          }
          if (!exists) {
            cuentasPorCuit.get(cuit).add(acc);
          }
          accountsById.put(acc.Id, acc);
        }
      }
    }
  }

  public static CuitResolverCache buildCuitResolverCache(
    Set<String> cuits,
    Set<Id> obtentorComercializaIds
  ) {
    CuitResolverCache cache = new CuitResolverCache();
    cache.cuentasPorCuit = queryCuentasPorCuitsNormalizados(cuits);
    cache.indexAccountsFromPorCuit();

    Set<Id> missingObtCom = new Set<Id>();
    if (obtentorComercializaIds != null) {
      for (Id obtId : obtentorComercializaIds) {
        if (obtId != null && !cache.accountsById.containsKey(obtId)) {
          missingObtCom.add(obtId);
        }
      }
    }
    if (!missingObtCom.isEmpty()) {
      for (Account acc : [
        SELECT Id, N_CUIT__c, Type, Name, RecordType.DeveloperName
        FROM Account
        WHERE Id IN :missingObtCom
      ]) {
        cache.accountsById.put(acc.Id, acc);
      }
    }
    return cache;
  }

  /** Aplica originante/destinatario en lote con una sola query de CUITs. */
  @TestVisible
  public static void aplicarOriginanteYDestinatarioBulk(
    List<Ventas_Informadas__c> ventas,
    Map<String, Id> obtentorComercializaByVariedad
  ) {
    if (ventas == null || ventas.isEmpty()) {
      return;
    }

    Set<String> cuits = new Set<String>();
    Set<Id> obtComIds = new Set<Id>();
    for (Ventas_Informadas__c venta : ventas) {
      if (venta == null) {
        continue;
      }
      String cuitOrig = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c);
      String cuitDest = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c);
      if (String.isNotBlank(cuitOrig)) {
        cuits.add(cuitOrig);
      }
      if (String.isNotBlank(cuitDest)) {
        cuits.add(cuitDest);
      }
      if (obtentorComercializaByVariedad != null && String.isNotBlank(venta.Variedad__c)) {
        Id obtId = obtentorComercializaByVariedad.get(venta.Variedad__c);
        if (obtId != null) {
          obtComIds.add(obtId);
        }
      }
    }

    CuitResolverCache cache = buildCuitResolverCache(cuits, obtComIds);
    for (Ventas_Informadas__c venta : ventas) {
      Id obtComId = obtentorComercializaByVariedad != null && String.isNotBlank(venta.Variedad__c)
        ? obtentorComercializaByVariedad.get(venta.Variedad__c)
        : null;
      aplicarOriginanteYDestinatario(venta, obtComId, cache);
    }
  }

  @TestVisible
  public static Map<String, Id> mapObtentorComercializaPorVariedad(Set<String> cultivaresInase) {
    Map<String, Id> out = new Map<String, Id>();
    if (cultivaresInase == null || cultivaresInase.isEmpty()) {
      return out;
    }
    for (Variedad__c v : [
      SELECT Cultivar_INASE__c, Obtentor_Comercializa__c
      FROM Variedad__c
      WHERE Cultivar_INASE__c IN :cultivaresInase AND Obtentor_Comercializa__c != NULL
    ]) {
      if (String.isNotBlank(v.Cultivar_INASE__c)) {
        out.put(v.Cultivar_INASE__c, v.Obtentor_Comercializa__c);
      }
    }
    return out;
  }

  /** Rol originante desde Account.Type o RecordType (misma lógica que reproceso / Nueva Venta). */
  @TestVisible
  public static void aplicarRolOriginante(Ventas_Informadas__c venta, Account originante) {
    if (venta == null || originante == null || String.isNotBlank(venta.Rol_Originante__c)) {
      return;
    }
    if (
      originante.RecordType != null &&
      originante.RecordType.DeveloperName == 'Proveedor'
    ) {
      return;
    }
    if (String.isNotBlank(originante.Type)) {
      venta.Rol_Originante__c = originante.Type;
      return;
    }
    if (
      originante.RecordType != null &&
      String.isNotBlank(originante.RecordType.DeveloperName)
    ) {
      venta.Rol_Originante__c = originante.RecordType.DeveloperName;
    }
  }

  @TestVisible
  public static void aplicarRolDestinatario(Ventas_Informadas__c venta, Account destinatario) {
    if (venta == null || destinatario == null || String.isNotBlank(venta.Rol_Destinatario__c)) {
      return;
    }
    String tipo = destinatario.Type;
    if (
      String.isBlank(tipo) &&
      destinatario.RecordType != null &&
      destinatario.RecordType.DeveloperName != 'Proveedor'
    ) {
      tipo = destinatario.RecordType.DeveloperName;
    }
    String cuitOrig = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c);
    String cuitDest = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c);
    if (tipo == 'Productor') {
      venta.Rol_Destinatario__c = 'Productor';
    } else if (tipo == 'Distribuidor' && cuitDest != cuitOrig) {
      venta.Rol_Destinatario__c = 'Distribuidor';
    } else if (tipo == 'Distribuidor' && cuitDest == cuitOrig) {
      venta.Rol_Destinatario__c = 'Productor';
    }
  }

  @TestVisible
  public static void aplicarVentaInterna(Ventas_Informadas__c venta) {
    aplicarVentaInterna(venta, null);
  }

  @TestVisible
  public static void aplicarVentaInterna(
    Ventas_Informadas__c venta,
    Map<Id, Account> accountsById
  ) {
    if (venta == null || venta.Venta_Interna__c != true) {
      return;
    }
    if (String.isNotBlank(venta.CUIT_Originante__c)) {
      venta.CUIT_Destinatario__c = venta.CUIT_Originante__c;
    }
    if (venta.Originante__c != null) {
      venta.Destinatario__c = venta.Originante__c;
      if (String.isBlank(venta.Razon_Social_Destinatario__c)) {
        Account orig = accountsById != null ? accountsById.get(venta.Originante__c) : null;
        if (orig == null) {
          List<Account> queried = [
            SELECT Name FROM Account WHERE Id = :venta.Originante__c LIMIT 1
          ];
          orig = queried.isEmpty() ? null : queried[0];
          if (orig != null && accountsById != null) {
            accountsById.put(orig.Id, orig);
          }
        }
        if (orig != null) {
          venta.Razon_Social_Destinatario__c = orig.Name;
        }
      }
    }
    venta.Rol_Destinatario__c = 'Productor';
  }

  @TestVisible
  public static void aplicarOriginanteYDestinatario(
    Ventas_Informadas__c venta,
    Id obtentorComercializaId
  ) {
    aplicarOriginanteYDestinatario(venta, obtentorComercializaId, (CuitResolverCache) null);
  }

  @TestVisible
  public static void aplicarOriginanteYDestinatario(
    Ventas_Informadas__c venta,
    Id obtentorComercializaId,
    CuitResolverCache cache
  ) {
    if (venta == null) {
      return;
    }

    venta.CUIT_Originante__c = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c);
    venta.CUIT_Destinatario__c = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c);
    if (venta.Venta_Interna__c != true) {
      venta.Venta_Interna__c = venta.CUIT_Destinatario__c == venta.CUIT_Originante__c
        && String.isNotBlank(venta.CUIT_Originante__c);
    }

    Set<String> cuits = new Set<String>();
    if (String.isNotBlank(venta.CUIT_Originante__c)) {
      cuits.add(venta.CUIT_Originante__c);
    }
    if (venta.Venta_Interna__c != true && String.isNotBlank(venta.CUIT_Destinatario__c)) {
      cuits.add(venta.CUIT_Destinatario__c);
    }
    if (cuits.isEmpty()) {
      if (venta.Venta_Interna__c == true) {
        aplicarVentaInterna(venta, cache != null ? cache.accountsById : null);
      }
      return;
    }

    Map<String, List<Account>> porCuit = cache != null
      ? cache.cuentasPorCuit
      : queryCuentasPorCuitsNormalizados(cuits);
    Map<Id, Account> obtComById = cache != null ? cache.accountsById : null;

    if (String.isNotBlank(venta.CUIT_Originante__c)) {
      Account originante = resolveCuentaPorCuit(
        venta.CUIT_Originante__c,
        obtentorComercializaId,
        porCuit.get(venta.CUIT_Originante__c),
        obtComById
      );
      if (originante != null) {
        venta.Originante__c = originante.Id;
        aplicarRolOriginante(venta, originante);
        if (cache != null) {
          cache.accountsById.put(originante.Id, originante);
        }
      }
    }

    if (venta.Venta_Interna__c == true) {
      aplicarVentaInterna(venta, cache != null ? cache.accountsById : null);
      return;
    }

    if (String.isNotBlank(venta.CUIT_Destinatario__c)) {
      Account destinatario = resolveCuentaPorCuit(
        venta.CUIT_Destinatario__c,
        obtentorComercializaId,
        porCuit.get(venta.CUIT_Destinatario__c),
        obtComById
      );
      if (destinatario != null) {
        venta.Destinatario__c = destinatario.Id;
        if (String.isBlank(venta.Razon_Social_Destinatario__c)) {
          venta.Razon_Social_Destinatario__c = destinatario.Name;
        }
        aplicarRolDestinatario(venta, destinatario);
        if (cache != null) {
          cache.accountsById.put(destinatario.Id, destinatario);
        }
      }
    }
  }
}