function parseJSON(data,rowToInsert,whereList){

  $j.each(data, function() {


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


    //Creamos un objeto fila
    var fila = {

                cultivo:document.createElement('td'),
                campana:document.createElement('td'),
                variedad:document.createElement('td'),
                tipo:document.createElement('td'),
                categoria:document.createElement('td'),
                um:document.createElement('td'),
                informadas:document.createElement('td'),
                distribuidor:document.createElement('td'),
                productor:document.createElement('td'),
                porcentajeProductor:document.createElement('td'),
                sinOrigen:document.createElement('td')
    };

    //Recorro las propiedades del objeto fila
    for(var propiedad in fila){
      
      var valor = (this[propiedad]==undefined)?'':this[propiedad];
      
      if(propiedad == 'porcentajeProductor' && this.hasOwnProperty('porcentajeProductor')){
	if(!isFirefox()){
        	fila[propiedad].innerText = toFixed(valor, 2)+'%';
        }else{
		fila[propiedad].textContent = toFixed(valor, 2)+'%';	
	}
      }else if(propiedad == 'informadas' || propiedad == 'distribuidor' || propiedad == 'productor' || propiedad == 'sinOrigen'){ 
        if(this.hasOwnProperty(propiedad)){
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
          
      //Seteo la clase CSS
      fila[propiedad].setAttribute('class','dataCell'+' '+propiedad);

      //Inserto la celda en la fila
      tr.appendChild(fila[propiedad]);

      if(this[propiedad]!=undefined && (propiedad == 'cultivo' || propiedad == 'campana') ){
        
        //Seteo el atributo data-isopen en false (Cerrado)
        fila[propiedad].setAttribute('data-isopen','false');
        
        //Seteamos un valor con lo que queremos que valla en el where
        fila[propiedad].setAttribute('data-wheredata',valor);

        //Seteamos la clausula where que hasta el momento usamos
        fila[propiedad].setAttribute('data-wherelist',JSON.stringify(whereList));

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
      }  
    }
  });
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
      for(var i = columna; i < columna + 3; i++){
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
        getDatos(fila, columna, whereList);

    }

}


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

//Funcion para formatear flotantes
function toFixed(value, precision) {
  var precision = precision || 0,
  neg = value < 0,
  power = Math.pow(10, precision),
  value = Math.round(value * power),
  integral = String((neg ? Math.ceil : Math.floor)(value / power)),
  fraction = String((neg ? -value : value) % power),
  padding = new Array(Math.max(precision - fraction.length, 0) + 1).join('0');

  return precision ? integral + ',' +  padding + fraction : integral;
}

//Funcion para determinar browser
function isFirefox(){
	return window.navigator.userAgent.indexOf("Firefox")!=-1;
}

function isChrome(){
	return window.navigator.userAgent.indexOf("Chrome")!=-1;
}
