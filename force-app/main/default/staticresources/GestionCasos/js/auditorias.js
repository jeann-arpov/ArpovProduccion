$j = jQuery.noConflict();
          
var nextIds = [];

var interaccion = null;



var tareas = [];


function showPopUpFechas(datosAProcesar,callback, modoContacto){
              
    //Obtenemos los comentarios codificados
    var comentarios = datosAProcesar.comentariosCodificados;
  
    //Por defecto ocultamos todas las fechas
     $j('#dtP1,#dtP2').hide();
  
    //Definimos que fechas voy a pedir en funcion de que comentarios codificados
    //se seleccionaron
  
    for(var i = 0; i < comentarios.length ; i++){

        var comentario = comentarios[i];

        if(comentario.indexOf('Promesa de Respuesta') != -1 || comentario.indexOf('Solicita tiempo de Respuesta') != -1){
            $j('#dtP1').show();
        }

        if(comentario.indexOf('Promesa de Pago') != -1 || comentario.indexOf('Solicita Plazo de pago') != -1){
            $j('#dtP2').show();
        }

    }
  
    $j.datepicker.regional['es'] = {
        closeText: 'Cerrar',
        prevText: '<Ant',
        nextText: 'Sig>',
        currentText: 'Hoy',
        monthNames: ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'],
        monthNamesShort: ['Ene','Feb','Mar','Abr', 'May','Jun','Jul','Ago','Sep', 'Oct','Nov','Dic'],
        dayNames: ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'],
        dayNamesShort: ['Dom','Lun','Mar','Mié','Juv','Vie','Sáb'],
        dayNamesMin: ['Do','Lu','Ma','Mi','Ju','Vi','Sá'],
        weekHeader: 'Sm',
        dateFormat: 'dd/mm/yy',
        firstDay: 1,
        isRTL: false,
        showMonthAfterYear: false,
        yearSuffix: ''
    };
  
    $j.datepicker.setDefaults($j.datepicker.regional['es']);
  
    $j( ".datepicker" ).datepicker();
  
    $j( "#dialog" ).dialog({
      resizable: false,
      modal: true,
      dialogClass: 'noTitleStuff',
      buttons: {
        'Aceptar': function() {
            
            
            //Removemos la clase de eror
            $j('#dtP1,#dtP2').removeClass('error');
            
            //Variable que indica si podemos procesar los datos
            var procesar = true;
            
            //Obtenemos los valores de ambas fechas
            
            if($j('#dtP1').is(':visible')){
            
                var fechaRespuesta = $j('#dtP1 .datepicker').val();
                
                //Verificamos que se ha ingresado un dato valido
                if(checkDate(fechaRespuesta.trim())){
                
                    //Hacemos un split de la fecha
                    fechaRespuesta = fechaRespuesta.split('/');
                    
                    //Agregamos los datos al objeto
                    datosAProcesar.fechaRespuesta = new Date(fechaRespuesta[2],fechaRespuesta[1]-1,fechaRespuesta[0]).toUTCString﻿();
                
                }else{

                    //Limpiamos el campo
                    $j('#dtP1 .datepicker').val('');
                    
                    //Indicamos que hay que completar el campo
                    $j('#dtP1').addClass('error');
                    
                    //Indicamos que no podemos procesar los datos
                    procesar = false;
                }
            
            }
            
            if($j('#dtP2').is(':visible')){
                
                var fechaPago = $j('#dtP2 .datepicker').val();
                
                if(fechaPago.trim() != ''){
                
                    //Hacemos un split de la fecha
                    fechaPago = fechaPago.split('/');
                
                    //Agregamos los datos al objeto
                    datosAProcesar.fechaPago = new Date(fechaPago[2],fechaPago[1]-1,fechaPago[0]).toUTCString﻿();
                
                }else{
                    
                    //Indicamos que hay que completar el campo
                    $j('#dtP2').addClass('error');
                    
                    //Indicamos que no podemos procesar los datos
                    procesar = false;
                }
            }
            
            //Verificamos si podemos procesar los datos
            if(procesar == true){
                
                //Cerramos el dialogo
                $j( this ).dialog( "close" );
                
                //Llamamos a la pantalla de loading
                $j( "#spinner" ).dialog({
                      resizable: false,
                      modal: true,
                      dialogClass: 'noTitleStuff'
                });
                
                if(interaccion === null){
                      crearInteraccion(modoContacto,function(){
                          procesarCasos(datosAProcesar,callback);
                      });
                }else{
                      procesarCasos(datosAProcesar,callback);
                }
            }
        },
        'Cancelar': function() {
            $j( this ).dialog( "close" );
        }
      }
  });
   
}

function guardar(callback){



    //Ocultamos la pantalla de mensajes
    $j('.message').hide();
  
    //Obtenemos los casos seleccionados
    var casos = $j('#jstree').jstree('get_selected');
  
    var idsCasos = [];

    // Indica si seleccionaron alguna auditoria
    var auditorias = false;
  
    for(var i in casos){
        
        var caso = casos[i];

        if(typeof(casos[i]) == 'string'){

            if(caso.startsWith(keyPrefixAuditoria) || caso.startsWith(idRecordTypeAuditoria)){
                auditorias = true;
            }
        
            idsCasos.push(caso);
        
        }

    }
  
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
  
    //Source list
    var sourceList = $j('.fc-source-fields')[0];
  
    var opciones = sourceList.children;
  
    var index = 0;
  
    //Obtenemos el comentario que es texto plano
    var descripcion = $j('.comentario').val();

    var taskType = $j('.taskType').val();


    var modoContacto = (taskType.toLowerCase() != 'visita') ? 'Telefono' : 'Visita'; 

    //Creamos un objeto
    var datosAProcesar = {
        
        idsCasos : idsCasos,
        comentariosCodificados : comentarios,
        descripcion : descripcion,
        tareas : tareas,
        interaccion :interaccion,
        parentCase : caseId,
        fechaRespuesta : null,
        fechaPago : null,
        taskType : taskType
    
    };

    // Si no selecciono un typo de tarea enviamos un mensaje al usuario
    if(taskType.length == 0){
        
        $j('<div><p>Debe seleccionar un tipo de tarea para grabar la gestión</p></div>').dialog({resizable: false,modal: true});

        return;
    
    }
    
    //Si no selecciono un comentario codificado o agrego un comentario mostramos mensaje indicando que debe seleccionar 
    // al menos un comentario codificado o tipear un comentario
    if(comentarios.length == 0 && descripcion.trim().length == 0){
    
        $j('<div><p>Debe seleccionar al menos un comentario codificado ó agregar un comentario para grabar la gestión</p></div>').dialog({resizable: false,modal: true});
        
        return;

    }

    // Si el tipo de gestión es Visita y no selecciona la auditoria, mostrar el mensaje de alerta: “Esta registrando una visita sin una auditoria asociada” —> Confirmar (graba) / Regresar (vuelve atras a la pantalla de gestion)
    if(!auditorias && taskType.toLowerCase() == 'visita'){
        
        $j('<div><p>Esta registrando una visita sin una auditoria asociada</p></div>').dialog({resizable: false,modal: true, buttons : {
        
                "Confirmar" : function() {
                    
                    $j(this).dialog("close");

                    grabar(datosAProcesar, callback, interaccion, modoContacto, mostrarPopUpFechas);

                },
            
                "Regresar" : function() {
                
                    $j(this).dialog("close");
                
                }
        
            }

        });

        return;
    
    }
  
    grabar(datosAProcesar, callback, interaccion, modoContacto, mostrarPopUpFechas);

}

function grabar(datosAProcesar, callback, interaccion, modoContacto, mostrarPopUpFechas){

    if(mostrarPopUpFechas){
        
        showPopUpFechas(datosAProcesar,callback,modoContacto);

    }else{

        //Llamamos a la pantalla de loading
        $j( "#spinner" ).dialog({
            resizable: false,
            modal: true,
            dialogClass: 'noTitleStuff'
        });

        if(interaccion === null){
            crearInteraccion(modoContacto,function(){
                procesarCasos(datosAProcesar,callback);
            });
        }else{
            procesarCasos(datosAProcesar,callback);
        }

    }

}

function mostrarMensaje(data){
    $j('.message').removeClass('warning');
    $j('.message').removeClass('success');
    if(data.casosProcesados > 0){
        $j('.message').show();
        $j('.message').addClass('success');
        $j('.message').html('Se han procesado '+'<strong>'+data.casosProcesados+' '+'casos'+'</strong>');
    }
}

function guardarYCrearRecordatorio(){
    guardar(redirigirRecordatorio);
}

function procesarCasosTratados(result, callback){

    // Llamamos a la funcion que limpia la pantalla para arrancar nuevamente
    clearWindows();
              
    //Llamamos a la pantalla de loading
    $j( "#spinner" ).dialog('close');

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
          
          if(result.hasOwnProperty('interaccionDeleted')){
              
              if(result.interaccionDeleted === true){
                  
                  //Debemos volver a generar la interaccion ya que fue borrada
                  //la misma solo se genera "on demmand"
                  interaccion = null;
                  
              }
              
          }
          
        }else{
          
          //No ocurrio un error
          
          if(callback != null){
            callback.call();
          }else{
            //Mostramos los resultados
            mostrarMensaje(result);
            //Refrescamos el arbol
            $j('#jstree').jstree("refresh"); 
            //Guardamos los resultados en la lista de tareas
            tareas = result.tareas;
          }    

        }

    }


}     