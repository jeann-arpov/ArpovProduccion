
var sourceList;

$j(document).ready(function(){

    var chooser = $j("#fieldChooser").fieldChooser();

    sourceList = $j("#sourceFields").clone();

    var sourceFields = $j("#sourceFields").children();
    chooser.getSourceList().add(sourceFields);

    //Creamos una interaccion por cada vez que se abre la pagina
    //crearInteraccion(modoContacto);

    $j('#jstree').bind('click', function(event) {
        detectaClickLink(event);
    });  

    $j('#jstree').jstree({
                            'core' : {
                                        'data' : function (obj, cb) {
                                                                        callGetNodo(obj,cb);

                                                                    },
                                        "check_callback" : true
                                    },
                            
                            "checkbox" : {
                                            "keep_selected_style" : false
                                        },

                            "plugins" : ["checkbox"]

                        }).bind("load_node.jstree", loadNode).bind("before_open.jstree", beforeOpen);

    $j('body').on('DOMNodeInserted', '#jstree', domNodeInserted);

}); 


/**
* @author Maximo Martinez
* @date 19/09/2014
* @description Obtiene los comentarios codificados seleccionados
*/
function getComentariosSeleccionados(){

  //Obtenemos las opciones elegidas
  var select = $j('.fc-destination-fields')[0];
  
  var opciones = select.children;
  
  var comentarios = [];
  
  var mostrarPopUpFechas = false;
  
  //Armamos una lista con los comentarios que se seleccionarion
  for(var i in opciones){
      var comentario = opciones[i].innerHTML;
      if(typeof(comentario) == 'string'){
          comentarios.push(comentario);
          
          //Verificamos si tenemos que mostrar el popu
          if(comentario.indexOf('Promesa de Respuesta')!=-1 || comentario.indexOf('Promesa de Pago')!=-1 || comentario.indexOf('Solicita tiempo de Respuesta')!=-1 || comentario.indexOf('Solicita Plazo de pago')!=-1){
              mostrarPopUpFechas = true;
          }
      }    
  }

  return {mostrarPopUpFechas: mostrarPopUpFechas, comentarios:comentarios};

}

function clearWindows(){

    // Limpiamos los comentarios
    $j('.comentario').val("");

    // Limpiamos los comentarios codificados
    var auxSourceList = sourceList.clone();
    var chooser = $j("#fieldChooser");
    chooser.empty();
    chooser = $j("#fieldChooser").fieldChooser();
    chooser.getSourceList().add(sourceList.children());
    sourceList = auxSourceList;

    // Deseleccionamos los casos
    $j('#jstree').jstree('deselect_all');
}

/**
* @author Maximo Martinez
* @date 27/08/2014
* @description Procesa una interaccion
*/
function procesarInteraccion(result,callback){
              
    if(result.hasOwnProperty('error')){
      
      if(result.error === true){
          
          if(result.hasOwnProperty('msg')){
                
              //Ocurrio un error, mostramos el mensaje de error
              $j('.message').show();
              $j('.message').removeClass('warning');
              $j('.message').removeClass('success');
              $j('.message').addClass('warning');
              $j('.message').html(result.msg);
              
          }
          
          //Llamamos a la pantalla de loading
          $j( "#spinner" ).dialog('close');
          
      }else{
          
          //No ocurrio un error, seteamos la interaccion y ejecutamos el callback
          
          if(result.hasOwnProperty('interaccion')){
          
              interaccion = result.interaccion;
              
              callback();
          
          }
      
      }
      
    }

}
/**
* @author Maximo Martinez
* @date 27/08/2014
* @description Despliega Popup Ventas
*/
function showPopUpVentas(evt){
              
      //Obtenemos el link
      var a = evt.target;
      
      //Obtenemos el id del caso
      var idCaso = a.getAttribute('data-id');
      
      //Llamamos a la remote action para obtener los datos
      
      //Al finalizar llamara a nuestra funcion de callback
      obtenerDatosVenta(idCaso,function(datos){
          
          //Con los datos armamos la url a nuestra VF
          
          var url = window.location.protocol;
          url += '//'
          url += window.location.host;
          url += '/apex/DrillDown?id=';
          url += datos.idCuenta+'&obtentor='+datos.idObtentor+'&cultivo='+datos.cultivo+'&campana='+datos.anoCampana;
          
          $j('<div></div>').append($j('<iframe width="900" height="400" />').attr('src', url)).dialog({
              
              resizable: false,
              modal: true,
              width:930,
              height:500
          
          });
          
      });
  
}

/**
* @author Maximo Martinez
* @date 27/08/2014
* @description Retorna el indice de un elemento dentro de un array y sino retorna -1
*/
function indexOf(needle) {
    if(typeof Array.prototype.indexOf === 'function') {
        indexOf = Array.prototype.indexOf;
    } else {
        indexOf = function(needle) {
            var i = -1, index = -1;

            for(i = 0; i < this.length; i++) {
                if(this[i] === needle) {
                    index = i;
                    break;
                }
            }

            return index;
        };
    }

    return indexOf.call(this, needle);
}

/**
* @author Maximo Martinez
* @date 27/08/2014
* @description Crea una tabla con un div como wrapper
*/

function createTable(className, dato){

    //Armamos un wrapper para la tabla
    var div = document.createElement('div');
    
    //Seteamos algunos atributos
    div.setAttribute('class',className);
    
    //Armamos una tabla
    var table = document.createElement('table');
    
    //Armamos un tbody
    var tbody = document.createElement('tbody');
    
    //Armamos un tr
    var tr = document.createElement('tr');
    
    //Creamos un td
    var td = document.createElement('td');
    
    td.innerHTML = dato.label;
    
    td.setAttribute('class','header');
    
    //Insertamos el td en el tr
    tr.appendChild(td);
    
    //Creamos un td
    td = document.createElement('td');
    
    td.innerHTML = dato.valor;
    
    td.setAttribute('class','data');
    
    //Insertamos el td en el tr
    tr.appendChild(td);
    
    //Insertamos el tr en la tabla
    table.appendChild(tr);

    //Insertamos la tabla en el div
    div.appendChild(table);

    //Retornamos el div
    return div;

}

/**
* @author Maximo Martinez
* @date 27/08/2014
* @description Se ejecuta cuando se carga un nodo
*/

function loadNode(e, data){

    var childrens = data.node.children;
    nextIds = [];
    for(var i in childrens){
        var id = childrens[i];
        if(typeof(id) != 'string')return;
        nextIds.push(id);
    }

}

/**
* @author Maximo Martinez
* @date 27/08/2014
* @description Se ejecuta antes de abrir un nodo
*/
function beforeOpen(e,data){

    if(data.node.parent == '#'){
        createDatatable(data.node.id);
    }

    var childrens = data.node.children;

    var listaPadres = new Array();
    var listaHijos = new Array();

    for(var i in childrens){
        listaPadres.push(childrens[i]);
    }

    while(listaPadres.length > 0){

        //Obtengo los datos del primer padre
        var id = listaPadres.pop();

        //Obtengo los datos del nodo
        var nodo = $j('#jstree').jstree('get_node', id);

        //Reviso si es un nodo valido
        if(nodo != false){

            //Reviso si tiene hijos
            if(nodo.children.length > 0){

                //Si tiene los agrego a la lista de padres
                for(var i in nodo.children){

                    listaPadres.push(nodo.children[i]);

                }

            }else{

                //Suponemos es hijo, lo agregamos a la lista de hijos
                listaHijos.push(id);

            }   

        }
         
    }
 
    //Recorremos los hijos y redibujamos la tabla
    for(var i in listaHijos){

        var id = listaHijos[i];

        if(typeof(id) == 'string'){
            createDatatable(id);
        }

    }

}

/**
* @author Maximo Martinez
* @date 27/08/2014
* @description Se ejecuta cuando se inserta un elemento al DOM
*/

function domNodeInserted(evt){
    createDatatable(null);
}


/**
* @author Maximo Martinez
* @date 27/08/2014
* @description comprueba que el formato de la fecha ingresada sea valido
*/
function checkDate(value){
    
    //Creamos una exprecion regular para saber si es una fecha
    var reg = /^(?:(?:31(\/|-|\.)(?:0?[13578]|1[02]))\1|(?:(?:29|30)(\/|-|\.)(?:0?[1,3-9]|1[0-2])\2))(?:(?:1[6-9]|[2-9]\d)?\d{2})$|^(?:29(\/|-|\.)0?2\3(?:(?:(?:1[6-9]|[2-9]\d)?(?:0[48]|[2468][048]|[13579][26])|(?:(?:16|[2468][048]|[3579][26])00))))$|^(?:0?[1-9]|1\d|2[0-8])(\/|-|\.)(?:(?:0?[1-9])|(?:1[0-2]))\4(?:(?:1[6-9]|[2-9]\d)?\d{2})$/;
    var regExp = new RegExp(reg);
    
    if(regExp.test(value)){
        return true;
    }else{
        return false;
    }
                
}

/**
* @author Maximo Martinez
* @date 27/08/2014
* @description Despliega popup
*/
function showPopUp(event){
   
    var pageY = event.pageY;  
    
    //Obtengo la celda
    var link = event.target;
    
    //Obtengo el atributo contiene el id del objeto a mostrar en el popup
    var id = link.getAttribute('data-id');
    
    //Obtengo el atributo contiene el conjunto de campos del objeto a mostrar en el popup
    var conjunto = link.getAttribute('data-conjunto');
    
    if(id){
        //Armamos la url de la pagina del pop up
        var url = {
                    protocol:window.location.protocol,
                    host:window.location.host,
                    path:'/apex/PopUpGestionCasos?conjunto='+conjunto+'&idObjeto='+id
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
            
            link.appendChild(popUp);
            
            $j('.popUp').show();  
            
        });
    }    
}

/**
* @author Maximo Martinez
* @date 27/08/2014
* @description Oculta un popup
*/
function hidePopUp(event){

    //Obtengo la celda
    var celda = event.target;

    //Si el popup existe
    if ($j('.popUp').length > 0) {
        //Elimino todos los pop up
        $j('.popUp').hide();
    }

}




/**
* @author Maximo Martinez
* @date 27/08/2014
* @description Crea la logica de tablas que muestran la información de un nodo
*/
function createDatatable(id){
                
   if(typeof(id) != 'string'){
       
        var id = null;
        
        //CreateDatatable se ejecuta cada vez que un nodo se crea
        for(var i in nextIds){
            if(document.getElementById(nextIds[i])){
                id = nextIds[i];
                nextIds.splice(i, 1);
                break;
            }
        }
    
    }
                
    if(typeof(id)!="string") return;
                  
    var children = $j('#jstree').jstree('get_node', id);
                
    if(children == false) return;
                
    var nodo = children.original;
                
    //Si tiene datable
    if(nodo.hasOwnProperty('datos') && nodo.parent != '#'){
                    
        var datos = nodo.datos;
                        
        if(jQuery.isEmptyObject( datos )) return;
                        
        if(datos.length == 0) return;
                        
        //Armamos un wrapper para la tabla
        var div = document.createElement('div');
                        
        //Seteamos algunos atributos
        div.setAttribute('class','node-list');
                        
        //Armamos una tabla
        var table = document.createElement('table');
                        
        //Armamos un tbody
        var tbody = document.createElement('tbody');
                        
        var index = 0;
        
        var tr = null;
                    
        //Recorremos los datos
        for(var i in datos){
                        
            //Obtenemos un dato
            var dato = datos[i];
                            
            if(typeof(dato) == "object"){
                                
                if(index % 2 == 0){
                    //Creamos un tr
                    tr = document.createElement('tr');
                }
                                
                //Creamos un td
                var td = document.createElement('td');
                                
                td.innerHTML = dato.label;
                
                td.setAttribute('class','header');
                                
                //Insertamos el td en el tr
                tr.appendChild(td);
                                
                //Creamos un td
                td = document.createElement('td');
                
                td.setAttribute('class','data');
                                
                //Verificamos si es linkeable
                if(dato.isLink){
                    //Creamos un link
                    var a = document.createElement('a');
                    a.setAttribute('href','/'+dato.id);
                    a.setAttribute('target','_blank');
                    a.innerHTML = dato.valor;
                    td.appendChild(a);
                }else{
                
                    //Seteamos la informacion
                    td.innerHTML = dato.valor;
                
                }
                            
                if(dato.showPopUp){
                    td.setAttribute('data-id',dato.id);
                    td.setAttribute('data-conjunto',dato.conjunto);
                    $j(td).hover(
                       function(event){
                           showPopUp(event);
                       },
                       function(event){
                           hidePopUp(event);
                       }
                    );
                }
                            
                //Insertamos el td en el tr
                tr.appendChild(td);
                
                //Insertamos el tr en la tabla
                table.appendChild(tr);
                
                index++;
                            
            }
                        
                        
        }
                    
                    
        //Si tenemos el atributo type
        if(nodo.hasOwnProperty('type')){
                        
            //Si el nodo es una venta
            var type = nodo.type;
                        
            if(type == 'Venta'){
                            
                if(index % 2 == 0){
                    //Creamos un tr
                    tr = document.createElement('tr');
                }
                                
                //Creamos un td
                var td = document.createElement('td');
                                
                td.innerHTML = '';
                
                td.setAttribute('class','header');
                
                //Insertamos el td en el tr
                tr.appendChild(td);
                
                //Creamos un td
                td = document.createElement('td');
                
                td.setAttribute('class','data');
               
                //Agregamos un link
                var a = document.createElement('a');
                
                a.innerHTML = 'Ver Ventas';
                
                //Agregamos un atributo que contendra el id del caso que luego usaremos
                a.setAttribute('data-id',nodo.id);
                
                //Agregamos el href
                a.setAttribute('href','#');
                
                $j(a).click(showPopUpVentas);
                
                td.appendChild(a);
                
                //Insertamos el td en el tr
                tr.appendChild(td);
                
                //Insertamos el tr en la tabla
                table.appendChild(tr);
                
                index++; 
                                 
            }
        }
                    
        if(datos.length % 2 != 0){
            //Creamos un td
            var td = document.createElement('td');
            //Creamos un td
            td = document.createElement('td');
                
            //Insertamos el td en el tr
            tr.appendChild(td);
            //Insertamos el td en el tr
            tr.appendChild(td);
        }
                   
        //Insertamos la tabla debajo de li
        var liPadre = document.getElementById(nodo.id);
    
        //Insertamos la tabla en el div
        div.appendChild(table);
                    
        if(!$j(liPadre).children('div.node-list')[0]) liPadre.appendChild(div);
                
    }else if(nodo.hasOwnProperty('datos') && nodo.parent == '#'){
                    
        //Obtenemos el primer dato del nodo
        var dato = nodo.datos[0];
        
        //Creamos un link 
        var a = document.createElement('a');
        
        //Seteamos algunos datos
        a.setAttribute('href','/'+dato.id);
        a.setAttribute('class','node-account');
        a.setAttribute('target','_blank');
        
        a.innerHTML = dato.valor;
        
        
        //Insertamos el link debajo de li
        var liPadre = document.getElementById(nodo.id);
        
        if(!$j(liPadre).children('a.node-account')[0])
            $j(a).insertAfter('#'+nodo.id+' > '+'a.jstree-anchor');
    }
                
                
    //Insertamos el wrapper debajo de li
    var liPadre = document.getElementById(nodo.id);
    
    //Si no habiamos creado antes esto
    if(!$j(liPadre).children('div.container-respuestas')[0]){
            
        //Armamos un contenedor de respuestas
        var divRespuestas = document.createElement('div');
    
        //Seteamos algunos atributos
        divRespuestas.setAttribute('class','container-respuestas');
            
        liPadre.appendChild(divRespuestas);
            
    }        
                
    if(nodo.hasOwnProperty('comentario_codificado')){
        
        var dato = nodo.comentario_codificado;
                    
        if(jQuery.isEmptyObject( datos ))return;
                    
        if(datos.length == 0) return;
                        
        var div = createTable('node-comentario',dato);
        
        //Insertamos dentro del container de respuestas
        var liPadre = document.getElementById(nodo.id);
        
        var containerRespuestas = $j(liPadre).children('div.container-respuestas');
        
        if(!containerRespuestas.children('div.node-comentario')[0])
            containerRespuestas.append(div);
        
    }
                
                
    if(nodo.hasOwnProperty('descripcion')){
                    
        var dato = nodo.descripcion;
                    
        if(jQuery.isEmptyObject( datos )) return;
                    
        if(datos.length == 0) return;

        var div = createTable('node-descripcion',dato);
        
        //Insertamos dentro del container de respuestas
        var liPadre = document.getElementById(nodo.id);
        
        var containerRespuestas = $j(liPadre).children('div.container-respuestas');
        
        if(!containerRespuestas.children('div.node-descripcion')[0])
            containerRespuestas.append(div);
        
    }
                
                
    if(nodo.hasOwnProperty('fecha')){
                    
        var dato = nodo.fecha;
                    
        if(jQuery.isEmptyObject( datos )) return;
                    
        if(datos.length == 0) return;
                        
        var div = createTable('node-fecha',dato);
        
        //Insertamos dentro del container de respuestas
        var liPadre = document.getElementById(nodo.id);
        
        var containerRespuestas = $j(liPadre).children('div.container-respuestas');
                
        if(!containerRespuestas.children('div.node-fecha')[0])
            containerRespuestas.append(div);
        
    }
                
                       
}


function detectaClickLink(event){
    //Obtenemos el elemento
    var elemento = event.target;
    //Si el elemento tiene el attributo data_type checkeo que tipo es
    if(elemento.hasAttribute('data_type')){

        //Obtengo el valor de data type
        var type = elemento.getAttribute('data_type');

        //Si es un nodo linkeable abro un tab nuevo con esa direccion
        if(type == 'node-link'){

            //Obtengo el href
            var href = elemento.getAttribute('href');

            //Abro un tab
            window.open(href);

        }

    }
}