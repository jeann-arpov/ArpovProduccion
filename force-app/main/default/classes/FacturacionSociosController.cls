public with sharing class FacturacionSociosController{

    public class MyException extends Exception{}
        
    public ApexPages.StandardSetController stdCon {get;set;}
    private String retURL;
    
    private String qry {get;set;}
    private String qryFilter {get;set;}
    private String qryOrder {get;set;}
    
    public List<Wrapper> socios{get;set;}
    private Set<ID> setNoElegidos;
    private Set<ID> setElegidos;
    public Boolean allSelected {get;set;}
    
    public final Integer recordsPerPage = 30;
    public Integer currentPageNumber {get;set;}
    public Boolean checkAllActive {get;set;}
    public Boolean showDetail {get;set;}

    public Integer totalRegistros {get;set;}
    public Integer pages {get;set;}
    public Integer currentPageNumber2 {get;set;}
    public Integer totalRegistrosOcultos {get;set;}

    //Segunda página
    public ERPvs__Comprobante_Venta__c cv {get;set;}
    public List<ListWrapper> pcvs{get;set;}
    public String textoAgregar{get;set;}

    //Empresas
    private Set<String> cuentasIds;
    public String empresaId{get;set;}

    public class Wrapper {
        public Boolean isChecked {get;set;}
        public Account socio {get;set;}
        
        public Wrapper(Boolean checked, Account socio){
            this.isChecked = checked;
            this.socio = socio;
        }
        
    }

    public class ListWrapper {
        public String categoriaSocio{get;set;}
        public ERPvs__Productos_Comprobante_de_Venta__c pcv {get;set;}
        
        public ListWrapper(ERPvs__Productos_Comprobante_de_Venta__c pcv){
            this.pcv = pcv;
        }
        
    }
    
    public FacturacionSociosController(){
        
        System.Debug(LoggingLevel.WARN,'FacturacionSociosController()');
        
        init();
        
    }

    //FL 2018-11-22: Lista de empresas
    public List<SelectOption> getEmpresas(){

      List<SelectOption> empresas = new List<SelectOption>();
        
      empresas.add(new  SelectOption('', '--Seleccione--'));

      for(ERPvs__Empresa__c e : [SELECT Id, Name FROM ERPvs__Empresa__c ORDER BY Name]){

        empresas.add(new  SelectOption(e.Id, e.Name));
      
      }

      return empresas;

    }

    public PageReference doSelectEmpresa(){

        cuentasIds = new Set<String>();
        for(Socio__c s : [SELECT Id, Name, Cuenta__c FROM Socio__c WHERE Empresa__c = :empresaId]){
            cuentasIds.add(s.Cuenta__c);
        }

        createQryFilter();

        System.Debug(LoggingLevel.WARN,'Qry: '+qry+qryFilter+qryOrder);

        stdCon = new ApexPages.StandardSetController(Database.getQueryLocator(qry+qryFilter+qryOrder));
        stdCon.setPageSize(recordsPerPage);

        return doSearch();

    }

    private void init(){
        
        qry = 'SELECT Id, Name, N_CUIT__c, ERPvs__Codigo_Postal_envio__c, Nombre_Obtentor__c, ERPvs__Localidad_envio__c, Provincia_Envio__c, Type, ';
        qry += 'ERPvs__Denominacion_Y_Razon_Social__c, ERPvs__Categoria_IVA__c, ERPvs__Identificacion_Tributaria__c, ERPvs__Direccion__c, ERPvs__Codigo_Postal__c, ERPvs__Localidad__c, ERPvs__Provincia_Departamento__c ';
        qry += 'FROM Account ';
        qryOrder = ' ORDER BY Name ASC';

        //createQryFilter();
    
        //System.Debug(LoggingLevel.WARN,'Qry: '+qry+qryFilter+qryOrder);
        
        //stdCon = new ApexPages.StandardSetController(Database.getQueryLocator(qry+qryFilter+qryOrder));
        //stdCon.setPageSize(recordsPerPage);
        
        retURL = ApexPages.currentPage().getParameters().get('retURL');

        //doSearch();
        
    }
    
    public PageReference doSearch(){
        System.Debug('doSearch');
        try{
            
            pages = Integer.valueOf(getTotalPages());
            
            currentPageNumber = stdCon.getPageNumber();
            currentPageNumber2 = currentPageNumber;
            setNoElegidos = new Set<ID>();
            setElegidos = new Set<ID>();
            allSelected = true;
            checkAllActive = false;
            getSocios();
            showDetail = true;
            totalRegistros = stdCon.getResultSize();
            
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
        return Page.facturacionSociosFirst;
        
    }
    
    private void createQryFilter(){
    
        //qryFilter = ' WHERE Es_Socio__c = true AND ERPvs__Activa__c = true';
        qryFilter = ' WHERE Es_Socio__c = true AND ERPvs__Activa__c = true AND Id = :cuentasIds';
    
    }
    
    public void getSocios(){
        System.Debug('getSocios');
        socios = new List<Wrapper>();
        Boolean exists;
        
        if(stdCon != null){
            List<Account> sociosPaginados = (List<Account>)stdCon.getRecords();
            System.Debug('sociosPaginados:' + sociosPaginados);
            for(Account a: sociosPaginados){
                if(allSelected){
                    if(setNoElegidos.contains(a.id)){
                        exists = false;
                    } else {
                        exists = true;
                    }
                } else {
                    if(setElegidos.contains(a.id)){
                        exists = true;
                    } else {
                        exists = false;
                    }
                }
                
                socios.add(new Wrapper(exists, a));
            }
        }
        
    }
    
    public PageReference doCancel(){
        return new PageReference(retURL != null ? retURL : '/home/home.jsp');
    }
    
    public Boolean getHasNext(){
        System.Debug('getHasNext');
        if(stdCon != null){
            return stdCon.getHasNext();
        }else{
            return false;
        }
    }
    
    public Boolean getHasPrevious(){
        System.Debug('getHasPrevious');
        if(stdCon != null){
            return stdCon.getHasPrevious();
        }else{
            return false;
        }   
    }
    
    private void controlaCheckeados(){
        System.Debug('controlaCheckeados');
        for(Wrapper w: socios){
            if(w.isChecked == true){
                setNoElegidos.remove(w.socio.Id);
                setElegidos.add(w.socio.Id);
            }else{
                setNoElegidos.add(w.socio.Id);
                setElegidos.remove(w.socio.Id);
            }    
        }
        checkAllActive = false;
    }
        
    
    public PageReference next(){
        System.Debug('next');
        try{
            if(stdCon != null){
                if(stdCon.getHasNext()){
                    controlaCheckeados();
                    stdCon.next();
                    currentPageNumber++;
                    currentPageNumber2 = currentPageNumber;
                    getSocios();
                }
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
        return null;
    }
    
    public PageReference previous(){
        System.Debug('previous');
        try{
            if(stdCon != null){
                if(stdCon.getHasPrevious()){
                    controlaCheckeados();
                    stdCon.previous();
                    currentPageNumber--;
                    currentPageNumber2 = currentPageNumber;
                    getSocios();
                }
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
        return null;
    }
    
    public void doFirst(){
        System.Debug('doFirst');
        try{
            if(stdCon != null){
                controlaCheckeados();
                currentPageNumber = 1;
                currentPageNumber2 = 1;
                stdCon.setpageNumber(1);
                getSocios();
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
    }
    
    public void doLast(){
        System.Debug('doLast');
        try{
            if(stdCon != null){
                controlaCheckeados();
                currentPageNumber = pages;
                currentPageNumber2 = pages;
                stdCon.setpageNumber(pages);
                getSocios();
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
    }
    
    
    public PageReference goToPage(){
        System.Debug('goToPage');
        try{
            if(stdCon != null){
                controlaCheckeados();
                if(currentPageNumber < 1)
                    currentPageNumber = 1;
                if(currentPageNumber > pages)
                    currentPageNumber = pages;
                currentPageNumber2 = currentPageNumber;
                stdCon.setPageNumber(currentPageNumber);
                getSocios();
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
        return null;
    }
    
    public PageReference goToPage2(){
        System.Debug('goToPage2');
        try{
            if(stdCon != null){
                controlaCheckeados();
                if(currentPageNumber2 < 1)
                    currentPageNumber2 = 1;
                if(currentPageNumber2 > pages)
                    currentPageNumber2 = pages;
                currentPageNumber = currentPageNumber2;
                stdCon.setPageNumber(currentPageNumber2);
                getSocios();
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
        return null;
    }
    
    public boolean getHasResults(){
        System.Debug('getHasResults');
        return (stdCon != null);
    }
    
    public String getPageNumber(){
        System.Debug('getPageNumber');
        String result = '';
        if(stdCon != null){
             result = stdCon.getPageNumber() + ' / ' + getTotalPages();
        }
        return result;
    }
    
    public String getTotalPages(){
        System.Debug('getTotalPages');
        if(stdCon != null){
            return String.valueOf(Integer.valueOf(Decimal.valueOf(stdCon.getResultSize()).divide(recordsPerPage, 0, System.RoundingMode.UP)));          
        }else{
            return '';
        }
    }
    
    public Integer getRecordViewFrom(){
        System.Debug('getRecordViewFrom');
        return totalRegistros > 0 ? 1 + (recordsPerPage * (currentPageNumber - 1)) : 0;
    }
    
    public Integer getRecordViewTo(){
        System.Debug('getRecordViewTo');
        Integer records = recordsPerPage + (recordsPerPage * (currentPageNumber - 1));
        return totalRegistros < records ? totalRegistros : records;
    }

    public PageReference doSecondPage(){

        controlaCheckeados();

        if((!allSelected && setElegidos.isEmpty()) || (allSelected && setNoElegidos.size() == totalRegistros)){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, 'Debe seleccionar al menos un socio.'));
            return null;
        } 

        cv = new ERPvs__Comprobante_Venta__c();

        Integer productsQty = 6;

        pcvs = new List<ListWrapper>();
        for(Integer i = 0; i < productsQty; i++){
            pcvs.add(new ListWrapper(new ERPvs__Productos_Comprobante_de_Venta__c()));
        }
        
        textoAgregar = '';

        return Page.facturacionSociosSecond;
    }

    public PageReference doSecondPageCancel(){

        return Page.facturacionSociosFirst;
        
    }

    public PageReference doSecondPageAllSelected(){

        allSelected = !allSelected;

        setElegidos.clear();
        setNoElegidos.clear();

        getSocios();

        return Page.facturacionSociosFirst;
        
    }

    public PageReference doGenerateInvoices(){

        try{
        
            Parametros_ERP_y_CRM__c param = [SELECT Punto_de_Venta_ARPOV__c, Canal_de_venta_ARPOV__c FROM Parametros_ERP_y_CRM__c LIMIT 1];
            //Obtengo los socios y los agrupo por categoría
            System.Debug(LoggingLevel.WARN,'allSelected:' + allSelected);
            System.Debug(LoggingLevel.WARN,'setNoElegidos:' + setNoElegidos);
            System.Debug(LoggingLevel.WARN,'setElegidos:' + setElegidos);
            List<Account> socios;
            if(allSelected){
                socios = [SELECT Id, Name, ERPvs__Categoria_socio__c FROM Account WHERE Es_Socio__c = true AND ERPvs__Activa__c = true AND ID NOT IN :setNoElegidos];
            } else {
                socios = [SELECT Id, Name, ERPvs__Categoria_socio__c FROM Account WHERE Es_Socio__c = true AND ERPvs__Activa__c = true AND ID IN :setElegidos];
            }
            if(socios.isEmpty()){
                throw new MyException('Debe seleccionar al menos un socio.');
            }
            //List<Account> socios = [SELECT Id, Name, ERPvs__Categoria_socio__c FROM Account WHERE Es_Socio__c = true AND ERPvs__Activa__c = true AND ID NOT IN :setNoElegidos];
            Map<String, List<Account>> mapCategoriaSocios = new Map<String, List<Account>>();
            for(Account a : socios){
                if(!mapCategoriaSocios.containsKey(a.ERPvs__Categoria_socio__c)){
                    mapCategoriaSocios.put(a.ERPvs__Categoria_socio__c, new List<Account>());
                }
                mapCategoriaSocios.get(a.ERPvs__Categoria_socio__c).add(a);
            }
            System.Debug(LoggingLevel.WARN,'socios:' + socios);
            System.Debug(LoggingLevel.WARN,'mapCategoriaSocios:' + mapCategoriaSocios);
            Map<String, List<ERPvs__Productos_Comprobante_de_Venta__c>> mapSocioProductos = new Map<String, List<ERPvs__Productos_Comprobante_de_Venta__c>>();
            //Recorro los productos y determino para que categorías de socio debo crear los PCV
            ERPvs__Productos_Comprobante_de_Venta__c pcvClone;
            Set<String> productosIds = new Set<String>();
            for(ListWrapper w : pcvs){
                if(w.pcv.ERPvs__Producto__c != null){
                    productosIds.add(w.pcv.ERPvs__Producto__c);
                    if(w.categoriaSocio == null){
                        for(Account s : socios){
                            pcvClone = w.pcv.clone(false);
                            if(!mapSocioProductos.containsKey(s.Id)){
                                mapSocioProductos.put(s.Id, new List<ERPvs__Productos_Comprobante_de_Venta__c>());
                            }
                            mapSocioProductos.get(s.Id).add(pcvClone);
                        }
                    } else {
                        if(mapCategoriaSocios.containsKey(w.categoriaSocio)){
                            for(Account s : mapCategoriaSocios.get(w.categoriaSocio)){
                                pcvClone = w.pcv.clone(false);
                                if(!mapSocioProductos.containsKey(s.Id)){
                                    mapSocioProductos.put(s.Id, new List<ERPvs__Productos_Comprobante_de_Venta__c>());
                                }
                                mapSocioProductos.get(s.Id).add(pcvClone);
                            }
                        }
                    }
                }
            }
            System.Debug(LoggingLevel.WARN,'mapSocioProductos:' + mapSocioProductos);
            //Por cada socio que tiene PCV para cargar, creo un CV y los inserto
            //cv.ERPvs__Empresa_Sucursal__c = param.Punto_de_Venta_ARPOV__c;
            //cv.ERPvs__Canal_de_venta__c = param.Canal_de_venta_ARPOV__c;
            cv.ERPvs__Sucursal__c = 0;
            Map<String, ERPvs__Comprobante_Venta__c> mapSocioCV = new Map<String, ERPvs__Comprobante_Venta__c>();
            ERPvs__Comprobante_Venta__c cvClone;
            for(String key : mapSocioProductos.keySet()){
                cvClone = cv.clone(false);
                cvClone.ERPvs__Cliente__c = key;
                mapSocioCV.put(key, cvClone);
            }
            
            System.Debug(LoggingLevel.WARN,'mapSocioCV:' + mapSocioCV);
            insert mapSocioCV.values();
            
            //Recorro los cv insertados para asignarles el id del CV a los PCV
            Map<String, ERPvs__Producto__c> mapProductos = new Map<String, ERPvs__Producto__c>();
            for(ERPvs__Producto__c p : [SELECT Id, Name, ERPvs__Descripcion_facturacion__c FROM ERPvs__Producto__c WHERe ID IN :productosIds]){
                mapProductos.put(p.Id, p);
            }
            List<ERPvs__Productos_Comprobante_de_Venta__c> pcvToInsert = new List<ERPvs__Productos_Comprobante_de_Venta__c>();
            Set<String> cvsIds = new  Set<String>();
            for(ERPvs__Comprobante_Venta__c cv : mapSocioCV.values()){
                for(ERPvs__Productos_Comprobante_de_Venta__c pcv : mapSocioProductos.get(cv.ERPvs__Cliente__c)){
                    pcv.ERPvs__Comprobante__c = cv.Id;
                    pcv.ERPvs__Codigo_de_barra__c = (mapProductos.get(pcv.ERPvs__Producto__c).ERPvs__Descripcion_facturacion__c == null ? mapProductos.get(pcv.ERPvs__Producto__c).Name : mapProductos.get(pcv.ERPvs__Producto__c).ERPvs__Descripcion_facturacion__c) + ' ' + textoAgregar;
                    cvsIds.add(cv.Id);
                }
                pcvToInsert.addAll(mapSocioProductos.get(cv.ERPvs__Cliente__c));
            }
    
            System.Debug(LoggingLevel.WARN,'pcvToInsert:' + pcvToInsert);
            insert pcvToInsert;
            
            //Genero vencimientos
            calcularVencimientos(cvsIds);
            
        } catch(Exception e) {
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
            return null;
        }
        
        ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Info, Label.FacturacionSociosController_1));
        
        return doSecondPage();
    }

    public List<SelectOption> getCategoriasSocios(){
    
        List<SelectOption> options = new List<SelectOption>();
        
        Set<String> tipos = new Set<String>();
        
        options.add(new SelectOption('', 'Todas'));
        
        Schema.DescribeFieldResult fieldResult = Account.ERPvs__Categoria_socio__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        
        for( Schema.PicklistEntry f : ple){
          options.add(new SelectOption(f.getLabel(), f.getValue()));
        }  
        
        return options;
    
    } 
    
    
    public static void calcularVencimientos(Set<String> cvsIds){
        
        String inicio;
        ERPvs__Detalle_Vencimiento_Ventas__C cuota;
        
        //datos del comprobante
        List<ERPvs__Comprobante_Venta__c> comprobantes = [SELECT id, Name, ERPvs__Total__c, ERPvs__Fecha__c, ERPvs__Contabilizar__c, ERPvs__Forma_de_Pago__c, ERPvs__Forma_de_Pago__r.ERPvs__Genera_vencimientos_Comprobante_Venta__c, ERPvs__Forma_de_Pago__r.ERPvs__Cantidad_Cuotas__c, ERPvs__Forma_de_Pago__r.ERPvs__Fecha_de_Inicio__c, ERPvs__Forma_de_Pago__r.ERPvs__Plazo_Libre__c, ERPvs__Forma_de_Pago__r.ERPvs__Porcentaje_Primera_Cuota__c, ERPvs__Forma_de_Pago__r.ERPvs__Plazo_entre_Cuotas__c FROM ERPvs__Comprobante_Venta__c WHERE id IN :cvsIds];
               
        List<ERPvs__Detalle_Vencimiento_Ventas__C> cuotas = new List<ERPvs__Detalle_Vencimiento_Ventas__C>();
        
        for(ERPvs__Comprobante_Venta__c comprobante : comprobantes){
            if(comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Genera_vencimientos_Comprobante_Venta__c == true){
                            
                inicio = comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Fecha_de_Inicio__c;
                    
                //Creo las cuotas
                Date d;
                
                if(inicio == 'Fecha Documento'){
                    d = comprobante.ERPvs__Fecha__c;
                }else if(inicio == 'Mes de Compra o Venta'){
                    d = comprobante.ERPvs__Fecha__c;
                    d = d.addMonths(1);
                    d.addDays(0-d.day()+1);
                }else if(inicio == 'Fecha Manual'){
                    d = comprobante.ERPvs__Fecha__c;
                }
                
                Decimal total = comprobante.ERPvs__Total__c;
                
                Decimal prt = 0;
                
                Integer qty = Integer.valueOf(comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Cantidad_Cuotas__c);
                
                // si tiene porcentaje a la primer cuota, le resto con 2 decimales al total ese porcentaje y considero que tengo 1 cuota menos
                if(comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Porcentaje_Primera_Cuota__c != null){
                    if(comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Porcentaje_Primera_Cuota__c > 0){
                        prt = math.floor(total * comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Porcentaje_Primera_Cuota__c) / 100;
                        total-=prt;
                        qty-=1;
                    }
                }
    
                
                List<Decimal> importes = calcularCuotas(total, qty); // calcula valor de 1era cuota y el resto de las cuotas
                
                
                // meto los datos a las cuotas            
                for(Integer i=0; i<comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Cantidad_Cuotas__c; i++){
                    
                    cuota = new ERPvs__Detalle_Vencimiento_Ventas__c();
                    
                    cuota.ERPvs__Cuota_Nro__c = i+1;
                    cuota.ERPvs__Comprobante__c = comprobante.id;
                    
                    //desplazamiento de dias
                    Integer plazo = Integer.valueOf(comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Plazo_Libre__c == null ? 0 : comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Plazo_Libre__c);
                    Integer entreCuotas = Integer.valueOf(comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Plazo_entre_Cuotas__c== null ? 0 : comprobante.ERPvs__Forma_de_Pago__r.ERPvs__Plazo_entre_Cuotas__c); 
                    
                    
                    if(i > 0){
                        plazo = entreCuotas  * i + plazo;
                        if(prt != 0){
                            if(i == 1){
                                cuota.ERPvs__Importe__c = importes[0];
                            }else{
                                cuota.ERPvs__Importe__c = importes[1];
                            }
                        }else{
                            cuota.ERPvs__Importe__c = importes[1];
                        }
                    }else{
                        if(prt != 0){
                            cuota.ERPvs__Importe__c = prt; 
                        }else{
                            cuota.ERPvs__Importe__c = importes[0];
                        }
                    }
                                    
                    cuota.ERPvs__Fecha_de_Vencimiento__c = d.addDays(plazo);
                    
                    cuotas.add(cuota);
                     
                }
            }
        }
        
        insert cuotas;
    }
    
    // 13/3 no daria exacto, asi que le tengo que meter distinta cuota a la primera que a las demas
    public static List<Decimal> calcularCuotas(Decimal num, Integer num_cuotas){
        List<Decimal> cuotas = new List<Decimal>();
        
        if(num_cuotas < 2) { // si tengo una cuota, no hago nada
            cuotas.add(num);
            cuotas.add(num);
            return cuotas;
        }
        
        num=num*100; // para sacar > 2 decimales y trabajar con enteros
        
        Decimal default1 = Integer.valueOf(math.floor(num/num_cuotas)); // posible valor de las num_cuotas-1 cuotas
        Decimal default2 = Integer.valueOf(math.ceil(num/num_cuotas)); // posible valor de las num_cuotas-1 cuotas
        
        if (default2*num_cuotas > num)  default2 = default1; // si me pase, hacer el ceil no valia
        
        //veo entre las 2 opciones de separar las cuotas, cual tiene menor distancia (diferencia entre la primer cuota y las demas)
        if (math.abs(num-default1*(num_cuotas-1)-default1) < math.abs(num-default2*(num_cuotas-1)-default2)){
           cuotas.add(((num-default1*(num_cuotas-1))/100)); 
           cuotas.add(default1/100); 
        }else{
           cuotas.add(((num-default2*(num_cuotas-1))/100)); 
           cuotas.add(default2/100);             
        }
       
        return cuotas;
    }

    public List<SelectOption> getCondicionesComerciales(){

        List<SelectOption> options = new List<SelectOption>();

        options.add(new  SelectOption('', '--Seleccione--'));

        for(ERPvs__Condicion_Comercial__c cc : [SELECT Id, Name FROM ERPvs__Condicion_Comercial__c ORDER BY Name ASC]){

            options.add(new  SelectOption(cc.Id, cc.Name));

        }

        return options;

    }

    public List<SelectOption> getProductos(){

        System.Debug('getProductos()');
        System.Debug('empresaId:' + empresaId);

        List<SelectOption> options = new List<SelectOption>();

        options.add(new  SelectOption('', '--Seleccione--'));

        for(ERPvs__Producto__c p : [SELECT Id, Name FROM ERPvs__Producto__c WHERE ERPvs__Empresa__c = :empresaId ORDER BY Name ASC]){

            options.add(new  SelectOption(p.Id, p.Name));

        }

        return options;

    }

    public List<SelectOption> getTiposComprobante(){

        List<SelectOption> options = new List<SelectOption>();

        options.add(new  SelectOption('', '--Seleccione--'));

        for(ERPvs__Tipo_comprobante_venta__c tcv : [SELECT Id, Name FROM ERPvs__Tipo_comprobante_venta__c WHERE ERPvs__Empresa__c = :empresaId ORDER BY Name ASC]){

            options.add(new  SelectOption(tcv.Id, tcv.Name));

        }

        return options;

    }

    public List<SelectOption> getSucursales(){

        List<SelectOption> options = new List<SelectOption>();

        options.add(new  SelectOption('', '--Seleccione--'));

        for(ERPvs__Sucursal__c s : [SELECT Id, Name FROM ERPvs__Sucursal__c WHERE ERPvs__Empresa__c = :empresaId ORDER BY Name ASC]){

            options.add(new  SelectOption(s.Id, s.Name));

        }

        return options;

    }

    public List<SelectOption> getCanalesVenta(){

        List<SelectOption> options = new List<SelectOption>();

        options.add(new  SelectOption('', '--Seleccione--'));

        for(ERPvs__Canal_de_venta__c cv : [SELECT Id, Name FROM ERPvs__Canal_de_venta__c ORDER BY Name ASC]){

            options.add(new  SelectOption(cv.Id, cv.Name));

        }

        return options;

    }
    
    
    
}