function deleteChildrens(celda){
    console.log(celda);
    
    //Seteamosla propiedad is open en false
    celda.setAttribute('data-isopen','false');
    
    //Obtengo mi padre
    var parentId =  celda.parentNode.getAttribute('data-parent');
    
    //Obtengo mi fila
    var fila = celda.parentElement.rowIndex;
    
    //Recorro las filas y elimino todas las que esten abajo y sean de diferente padre 
    
    //Obtengo la tabla
    var tabla = document.getElementById('tablaVentas');
    
    //Obtengo las filas de la tabla
    var filas = tabla.rows;
    
    while((filas[fila+1].getAttribute('data-parent') != parentId && (parseInt(filas[fila+1].getAttribute('data-parent')) >= parseInt(parentId))) && fila<filas.length){
        //Elimino la fila
        tabla.deleteRow(fila+1);
    }
}



function createChildrens(celda){
    //Obtengo el numero de fila
    var fila = celda.parentElement.rowIndex - 1;
    
    //Obtengo numero de columna
    var columna = celda.cellIndex;
    
    //Obtengo el numero de fila
    var fila = celda.parentElement.rowIndex - 1;
    
    //Obtengo los valores de clausula where
    var whereList = JSON.parse(celda.getAttribute('data-wherelist'));
    
    if(columna < 3){
      //Agrego la el valor del atributo wheredate
      whereList.push(celda.getAttribute('data-wheredata'));
    }else if(columna == 3){
      //La clausula where llevara tres valores mas en lugar de uno
      var childList = celda.parentNode.childNodes;
      for(var i = columna; i < columna + 4; i++){
          whereList.push(childList[i].getAttribute('data-wheredata'));
      }
    }
    
    
    console.log(whereList);
    
    //Seteamos la propiedad is open en true
    celda.setAttribute('data-isopen','true');
    
    //Checkeo si tengo los datos en cache
    var datosDeCache = getCache(fila, columna, whereList);

    if(datosDeCache != false && datosDeCache){
        
        parseJSON(datosDeCache,fila+1,whereList);
        
    }else{
        
        //Hago un RemoteAction 
        drillDown(fila, columna, whereList);

    }
}

function parseJSON(json,rowToInsert,whereList){
     $j.each(json, function() {
		
	    //Creo una fila
	    //Obtengo el cuerpo de la tabla
	    var tbody = document.getElementById('tablaVentas').getElementsByTagName('tbody')[0];

	    //Comprobamos que existan filas en la tabla
	    if(tbody.rows.length == 0)
		rowToInsert = 0;

	    //Creo una nueva fila para la tabla en el lugar indicado
	    var tr = tbody.insertRow(rowToInsert);

	    //Inserto el atributo padre
	    tr.setAttribute('data-parent',rowToInsert);

	    //Seteo la clase CSS
	    tr.setAttribute('class','dataRow');              

              var fila = {
                  
                  cultivo:document.createElement('td'),
                  campana:document.createElement('td'),
                  obtentor:document.createElement('td'),
                  variedad:document.createElement('td'),
                  tipo:document.createElement('td'),
                  categoria:document.createElement('td'),
                  um:document.createElement('td'),
                  cuitOriginante:document.createElement('td'),
                  tipoVenta:document.createElement('td'),
                  cuitDestinatario:document.createElement('td'),
                  cantidad:document.createElement('td')
              
              };
              
              //Recorro las propiedades del objeto fila
              for(var propiedad in fila){
                  
                  var valor = (this[propiedad]==undefined)?'':this[propiedad];
                  if(propiedad == 'tipoVenta'){
                      
                      if(this.hasOwnProperty('id')){
                          
                          //Creamos un objeto link
                          var link = document.createElement('a');
                          
                          //Obtenemos la url de la org
                          var host = window.location.host;
                          var protocol = window.location.protocol; 
                          
                          //Obtenemos el id dela venta
                          var id = this['id'];
                          
                          //Seteamos el atributo href del link
                          link.setAttribute('href',protocol+'//'+host+'/'+id);
                          
                          //Seteamos el atributo target 
                          link.setAttribute('target','_blank');
                          
                          //Agregamos el tipo de venta
			  if(!isFirefox()){
                          	link.innerText = valor;
                          }else{
			  	link.textContent = valor;
			  }
                          //Agregamos el link al la celda
                          fila[propiedad].appendChild(link);
                      }  
                                                           
                  }else if(propiedad == 'obtentor'){
                      
                      //Almaceno el id del obtentor en un atributo
                      fila[propiedad].setAttribute('data-obtentor',valor);
                      
                      //Obtengo el nombre del obtentor que sera el que muestro en el nombre
		      if(!isFirefox()){	
                      	fila[propiedad].innerText = (this[propiedad]==undefined)?'':this['obtentorName'];
                      }else{
		      	fila[propiedad].textContent = (this[propiedad]==undefined)?'':this['obtentorName'];
		      }	
                  }else if (propiedad == 'cantidad') {
                    if (this.hasOwnProperty(propiedad)){
			if(!isFirefox()){                      
				fila[propiedad].innerText = thousandSeparator(this[propiedad]);
			}else{
				fila[propiedad].textContent = thousandSeparator(this[propiedad]);			
			}
		    }	
                  }else{    
		    if(!isFirefox()){	
                    	fila[propiedad].innerText = valor;
		    }else{
			fila[propiedad].textContent = valor;				                  
		    }	
		 }
                  
                  if(propiedad == 'cuitOriginante' && this.hasOwnProperty('originanteId')){
                      
                      //Seteamos un atributo con el id de la cuenta
                      fila[propiedad].setAttribute('data-cuenta',this['originanteId']);
                      
                  }else if(propiedad == 'cuitDestinatario' && this.hasOwnProperty('destinatarioId')){
                      
                      //Seteamos un atributo con el id de la cuenta
                      fila[propiedad].setAttribute('data-cuenta',this['destinatarioId']);
                  
                  }
                  if(propiedad == 'cultivo' || propiedad == 'campana' || propiedad == 'variedad' || propiedad == 'obtentor' || propiedad == 'tipo' || propiedad == 'categoria' || propiedad == 'um'){
		          //Seteamos un valor con lo que queremos que valla en el where
		          fila[propiedad].setAttribute('data-wheredata',valor);
		          
		          //Seteamos la clausula where que hasta el momento usamos
		          fila[propiedad].setAttribute('data-wherelist',JSON.stringify(whereList));
                  }
                  //Seteo la clase CSS
                  fila[propiedad].setAttribute('class','dataCell'+' '+propiedad);
                  
                  if(this[propiedad]!=undefined && (propiedad == 'cultivo' || propiedad == 'campana' || propiedad == 'variedad' || propiedad == 'obtentor') )
                      fila[propiedad].setAttribute('data-isopen','false');
              }
              
             
              
              //Inserto cada td en la fila creada
              for(var propiedad in fila){                             
                  tr.appendChild(fila[propiedad]);
                  
                  if(propiedad == 'cultivo' || propiedad == 'campana' || propiedad == 'variedad' || propiedad == 'obtentor'){
                  
                      $j(fila[propiedad]).click(function(event){
                  
                          event.preventDefault();
                          
                          //Se hace click en una celda
                          //Obtengo la celda
                          var celda = event.target;
                          
                          //Si no tiene el atributo data-isopen no es expandible
                          if(!celda.hasAttribute('data-isopen'))
                              return;
                          
                          //Compruebo que la propiedas isopen
                          var isOpen = celda.getAttribute('data-isopen');
                          if(isOpen.trim() == "false")
                              createChildrens(celda);
                          else
                              deleteChildrens(celda);
                              
                          
                      });
                   }else if(propiedad == 'cuitOriginante' || propiedad == 'cuitDestinatario'){
                       
                       $j(fila[propiedad]).hover(
                           function(event){
                               showPopUp(event);
                           },
                           function(event){
                               hidePopUp(event);
                           }
                       );
                       
                   }
              }
              
              
              
          });
          
          
}

function hidePopUp(event){
    //Obtengo la celda
    var celda = event.target;
    
    //Si el popup existe
    if ($j('.popUp').length > 0) {
        //Elimino todos los pop up
        $j('.popUp').hide();
    }
    
    
}

function showPopUp(event){
   
    var pageY = event.pageY;  
    
    //Obtengo la celda
    var celda = event.target;
    
    //Obtengo el atributo cuenta que contiene el id de la cuenta a mostrar en el popup
    var id = celda.getAttribute('data-cuenta');
    
    if(id){
        //Armamos la url de la pagina del pop up
        var url = {
                    protocol:window.location.protocol,
                    host:window.location.host,
                    path:'/apex/popUpCuenta?id='+id
                  };
        
        //Hacemos una llamada Ajax
        $j.get( url.protocol+'//'+url.host+url.path, function( data ) {
            
            //Si el popup no existe
            if ($j('.popUp').length == 0) {
                $j(document.body).append('<div class="popUp"></div>');
            }
            //Optenemos el pop up y seteamos el contenido
            $j('.popUp').html('');
            
            var popUp = $j('.popUp')[0];
            
            popUp.innerHTML = data;
            
            celda.appendChild(popUp);
            
            $j('.popUp').show();  
	    
	    if(parseInt($j('.datagrid').css("padding-bottom").replace('px',''))<$j('.popUp').outerHeight())	
	    	$j('.datagrid').css("padding-bottom",$j('.popUp').outerHeight()+'px'); 

	    //checkScroll(pageY)	

        });
    }    
}

//Administracion de cache
function saveCache(fila, columna, whereList, data){

  //Usamos el session storage de HTML5
  if(typeof(Storage)!=="undefined"){
      
      var key = JSON.stringify(fila+columna+whereList);
      
      if(!sessionStorage.hasOwnProperty(key)){
          
          var value = JSON.stringify(data);
          
          sessionStorage.setItem(key,value);
          
      }
      
  }

}

function getCache(fila, columna, whereList){

  //Usamos el session storage de HTML5
  if(typeof(Storage)!=="undefined"){
      
      var key = JSON.stringify(fila+columna+whereList);
      
      if(sessionStorage.hasOwnProperty(key)){
           
           var value = sessionStorage.getItem(key);
           
           return JSON.parse(value);
       }
  }

  return false;

}

//Finds y value of given object
function findPos(obj) {
	var curtop = 0;
	if (obj.offsetParent) {
		do {
			curtop += obj.offsetTop;
		} while (obj = obj.offsetParent);
	return [curtop];
	}
}


function checkScroll(pageY){
	console.log($j(document).scrollTop() ,$j('.popUp').outerHeight());
	if((pageY+$j('.popUp').outerHeight()) >= (iframeHeight+$j(document).scrollTop())){
		var newScrollTop = 0;		
		if($j(document).scrollTop() < $j('.popUp').outerHeight()){
			newScrollTop= $j(document).scrollTop() + ($j('.popUp').outerHeight()-$j(document).scrollTop());
			
		}else if($j(document).scrollTop() == $j('.popUp').outerHeight()){
			newScrollTop= $j(document).scrollTop() + $j('.popUp').outerHeight();
			
		}else{
			newScrollTop= $j(document).scrollTop() + ($j(document).scrollTop()-$j('.popUp').outerHeight());
			
		}
		$j('html, body').animate({'scrollTop': newScrollTop}, 'slow');	
	}
}

function clearCache(){
  //Usamos el session storage de HTML5
  if(typeof(Storage)!=="undefined"){
      sessionStorage.clear();
  }
}

//Utilidades
//Funcion para separar miles
function thousandSeparator(n) {
    n += '';
    x = n.split('.');
    x1 = x[0];
    x2 = x.length > 1 ? '.' + x[1] : '';
    var rgx = /(\d+)(\d{3})/;
    while (rgx.test(x1)) {
            x1 = x1.replace(rgx, '$1' + '.' + '$2');
    }
    return x1 + x2;
}

//Funcion para determinar browser
function isFirefox(){
	return window.navigator.userAgent.indexOf("Firefox")!=-1;
}

function isChrome(){
	return window.navigator.userAgent.indexOf("Chrome")!=-1;
}
