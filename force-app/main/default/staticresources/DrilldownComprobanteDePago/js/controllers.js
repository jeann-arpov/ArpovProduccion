app.controller('DrillDownController', function($scope,$sce,RemoteAction){
	
	$scope.spinner = {show:true};

	this.init = function(){
		
		console.log('controller init');

		$scope.getComprobantesDePagoByCliente = RemoteAction(remoteActions.getComprobantesDePagoByCliente,accountId);     
        
        $scope.getComprobantesDePagoByCliente.then(function(result) {  
           	

            for(var i = 0; i < result.length; i++){
            	result[i].isOpen = false;
            }

            console.log(result);

            $scope.comprobantesDePago = result;

            $scope.spinner.show = false;

        });

	}

	this.toTrusted = function(htmlString){
		return htmlDecode(htmlString);
	}

	this.openComprobante = function(comprobante){
		
		comprobante.isOpen = true;

		// Si ya lo tragimos no volvemos a hacer la llamada
		if(comprobante.Valores__r){
			return;
		}

		$scope.spinner.show = true;

		// Traemos valores desde Salesforce
		$scope.getValoresByComprobante = RemoteAction(remoteActions.getValoresByComprobante,comprobante.Id);

		$scope.getValoresByComprobante.then(function(result) {  

		
        	if(!result.length){
        		comprobante.isNoData = true;
        	}

            for(var i = 0; i < result.length; i++){
            	result[i].isOpen = false;
            }

            console.log(result);

            comprobante.Valores__r = result;

            $scope.spinner.show = false;

        });

	}

	this.closeComprobante = function(comprobante){
		
		comprobante.isOpen = false;

	}

	this.closeValor = function(valor){

		valor.isOpen = false;

	}

	this.openValor = function(valor){

		valor.isOpen = true;

		// Si ya lo tragimos no volvemos a hacer la llamada
		if(valor.Aplicaciones__r){
			return;
		}

		$scope.spinner.show = true;

		// Traemos valores desde Salesforce
		$scope.getAplicacionesByValor = RemoteAction(remoteActions.getAplicacionesByValor,valor.Id);

		$scope.getAplicacionesByValor.then(function(result) {  
           	
           	if(!result.length){
        		valor.isNoData = true;
        	}

           	console.log(result);

            valor.Aplicaciones__r = result;

            $scope.spinner.show = false;

        });

	}

	// Inicializamos controlador
	this.init();


	$scope.$watch('comprobantesDePago', function() {
    	
    	var index = 0;

    	if(!$scope.comprobantesDePago){
    		return;
    	}

    	for(var i = 0; i < $scope.comprobantesDePago.length ; i++){

    		var comprobante = $scope.comprobantesDePago[i];

    		comprobante.index = index;

    		index++;

    		if(!comprobante.Valores__r || !comprobante.isOpen){
    			continue;
    		}

    		if(comprobante.Valores__r.length == 0){
    			comprobante.isNoDataIndex = index;
    			index++;
    			continue;
    		}

    		for(var j = 0; j < comprobante.Valores__r.length; j++){

    			var valor = comprobante.Valores__r[j];

    			valor.index = index;

    			index++;

    			if(!valor.Aplicaciones__r || !valor.isOpen){
    				continue;
    			}

    			if(valor.Aplicaciones__r.length == 0){
    				valor.isNoDataIndex = index;
    				index++;
    				continue;
	    		}

    			for(var k = 0; k < valor.Aplicaciones__r.length; k++){

    				var aplicacion = valor.Aplicaciones__r[k];

    				aplicacion.index = index;

    				index++;

    			}

    		}

    	}

    },true);

});