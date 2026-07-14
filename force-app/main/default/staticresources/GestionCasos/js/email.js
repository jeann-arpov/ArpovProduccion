$j = jQuery.noConflict();
          
var nextIds = [];

var interaccion = null;

var modoContacto = 'Email Saliente';

var tareas = [];

function enviarEmail(){
              
	//Obtenemos los casos seleccionados
	var casos = $j('#jstree').jstree('get_selected');

	var idsCasos = [];

	for(var i in casos){
	  if(typeof(casos[i]) == 'string'){
	      idsCasos.push(casos[i]);
	  }
	}

	//Obtenemos los comentarios seleccionados
	var getComentarios = getComentariosSeleccionados();

	if(idsCasos.length === 0){
	  //Mostramos mensaje indicando que debe seleccionar al menos un comentario codificado
	  //o tipear un comentario
	  $j('<div><p>Debe seleccionar al menos un caso para grabar la gestión</p></div>').dialog({resizable: false,modal: true});
	  return;
	}

	var datosProcesar = {
	  
	  idsCasos : idsCasos,
	  parentCase : caseId,
	  interaccion : interaccion,
	  comentariosCodificados : getComentarios.comentarios
	  
	};

	//Llamamos a la pantalla de loading
	$j( "#spinner" ).dialog({
	  resizable: false,
	  modal: true,
	  dialogClass: 'noTitleStuff'
	});

	if(interaccion === null){
	  crearInteraccion(modoContacto,function(){
	      procesarCasos(datosProcesar);
	  });
	}else{
	  procesarCasos(datosProcesar);
	}
}

function procesarResultado(result){

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
	      
	      
	      //Redirigimos a la standard page de email
	      var url = '/_ui/core/email/author/EmailAuthor?p2_lkid=001J000001FcqXl&rtype=003&p3_lkid='+caseId+'&retURL='+caseId;
	      window.location.href = url;
	         
	  
	  }
	  
	}


}