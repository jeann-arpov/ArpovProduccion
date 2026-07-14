$j = jQuery.noConflict();

function openModal(url, title){

    console.log(url);
    console.log(title);

    $j('#myModalLabel').html(title);

    $j('#modalIFrame').attr('src', url);
    
    $j('#modalIFrame').load(function(){
        $j('#pdfModal').modal('show'); 
    });

    // Prevent scrolling to the top
    return false;
}

function checkNumber(objeto){
                
    //Obtenemos el valor del objeto
    var valor = objeto.value;
    
    //Creamos una exprecion regular para saber si es un numero
    var reg = /^\d+(\.0)?$/;
    var regExp = new RegExp(reg);
    
    //Checkeamos que sea un numero
    if(regExp.test(valor)){
        
        //Checkeamos que sea mayor a 0
        if(parseInt(valor) >= 0){
            
            setearEstadoExito(objeto);
           
        }else{
            
            //La cantidad no puede ser igual o menor a 0
            setearEstadoError(objeto);
        
        }
        
    }else{
        
        if(valor == ''){
        
            //Resetamos el estado
            resetearEstado(objeto);
            
        }else{
            
            //El valor no puede ser un valor no numerico
            setearEstadoError(objeto);
        
        }
    }
        
}

function getLineasVariedades(){

    var inputs = $j('.item-data');
    
    var cuples = {};
    
    for(var i = 0; i < inputs.length ; i++){
        
        var input = inputs[i];

        if(input.className.indexOf('kilos_')!=-1 || input.className.indexOf('hectareas_')!=-1){

            var lista = input.className.split(' ');

            for(var j = 0 ; j < lista.length ; j++){

                var class_ = lista[j];

                if(class_.indexOf('kilos_')!=-1){

                    var index_ = parseInt(class_.replace('kilos_',''));

                    if(typeof(cuples[index_])=="object"){
                        cuples[index_]['kilos']=input.value;
                    }else{
                        cuples[index_] = {'kilos':input.value};
                    }


                }else if(class_.indexOf('hectareas_')!=-1){

                    var index_ = parseInt(class_.replace('hectareas_',''));

                    if(typeof(cuples[index_])=="object"){
                        cuples[index_]['hectareas']=input.value;
                    }else{
                        cuples[index_] = {'hectareas':input.value};
                    }

                }

            }

        }
        
    }

    return cuples;

}


function checkString(objeto){
    //Obtenemos el valor del objeto
    var valor = objeto.value.trim();
    
    //Creamos una exprecion regular para saber si es un nombre valido
    var reg = /^([A-Za-z]*[ ÁÉÍÓÚéóíúáàëñÑA-Za-z]*)$/;
    var regExp = new RegExp(reg);
    
    //Checkeamos que sea un numero
    if(regExp.test(valor) && valor != ''){
        
        
            setearEstadoExito(objeto);
        
    }else{
        
        if(valor == ''){
        
            //Resetamos el estado
            resetearEstado(objeto);
            
        }else{
            
            //El valor corresponde con la expresion regular
            setearEstadoError(objeto);
        
        }
    }
}

function setearEstadoExito(objeto){
     //Removemos el estado de error
     $j(objeto).parent().removeClass('has-error');
    
     //Seteamos el estado del input en success
     $j(objeto).parent().addClass('has-success');
     
     //Removemos el icono de error
     $j(objeto).parent().children('.glyphicon').removeClass('glyphicon-remove');
     
     //Seteamos el icono de exito
     $j(objeto).parent().children('.glyphicon').addClass('glyphicon-ok');
}

 
function setearEstadoError(objeto){
     //Removemos el estado de exito
     $j(objeto).parent().removeClass('has-success');
    
     //Seteamos el estado del input en error
     $j(objeto).parent().addClass('has-error');
     
     //Removemos el icono de exito
     $j(objeto).parent().children('.glyphicon').removeClass('glyphicon-ok');
     
     //Seteamos el icono de error
     $j(objeto).parent().children('.glyphicon').addClass('glyphicon-remove');
}

function resetearEstado(objeto){
    
    //Removemos el estado de exito
     $j(objeto).parent().removeClass('has-success');
    
    //Removemos el estado de error
    $j(objeto).parent().removeClass('has-error');
    
    //Removemos el icono de exito
    $j(objeto).parent().children('.glyphicon').removeClass('glyphicon-ok');
    
    //Removemos el icono de error
    $j(objeto).parent().children('.glyphicon').removeClass('glyphicon-remove');
    
}
            
function checkFormData(callback,isConfirmationStage){
    
    //Ocultamos el mensaje de error
    hideMessage();
    
    //Obtenemos los input del form
    var inputs = $j('.form-kilos :input').not('.novalidate');
    
    //Variable que indica valor a retornar
    var submitForm = true;
    
    //Recorremos cada input y coleccionamos sus valores
    inputs.each(function() {
        
        var value = ($j(this).val() == null)?'':$j(this).val().trim();
        var type = $j(this).attr('type');
        resetearEstado(this);
        if(value == '' && type != 'button'){
            setearEstadoError(this);
            submitForm = false;
        }
        
    });


    
    if(submitForm && $j('.has-error').length == 0){

        if(!isConfirmationStage){

            // Obtenemos las lineas 
            var lineas = getLineasVariedades();

            var lineaInformada = false;

            for(var key in lineas){

                if(lineas[key].kilos != "" || lineas[key].hectareas != ""){
                    lineaInformada = true;
                    break;
                }

            }

            if(lineaInformada != true){
                showMessage('Debe existir al menos una linea informada','error');
                return;
            }

        }
            
        callback.call();
        
    }else{

        showMessage('Debe completar los campos resaltados en rojo.','error');
    
    }
    
}


function checkFormCheckbox(objeto){
    
    //Obtenemos el valor del objeto
    var valor = objeto.value.trim();
    
    if(valor == ''){
        
        
        setearEstadoError(objeto);
            
    }else{
        
        
        setearEstadoExito(objeto);
    
    }
    
    return true;
}
            
function checkDate(objeto){
    //Obtenemos el valor del objeto
    var valor = objeto.value.trim();
    
    //Creamos una exprecion regular para saber si es una fecha
    var reg = /^(?:(?:31(\/|-|\.)(?:0?[13578]|1[02]))\1|(?:(?:29|30)(\/|-|\.)(?:0?[1,3-9]|1[0-2])\2))(?:(?:1[6-9]|[2-9]\d)?\d{2})$|^(?:29(\/|-|\.)0?2\3(?:(?:(?:1[6-9]|[2-9]\d)?(?:0[48]|[2468][048]|[13579][26])|(?:(?:16|[2468][048]|[3579][26])00))))$|^(?:0?[1-9]|1\d|2[0-8])(\/|-|\.)(?:(?:0?[1-9])|(?:1[0-2]))\4(?:(?:1[6-9]|[2-9]\d)?\d{2})$/;
    var regExp = new RegExp(reg);
    
    if(regExp.test(valor)){
        setearEstadoExito(objeto);
    }else{
        setearEstadoError(objeto);
    }
    
}
            
function checkEquals(objeto,tipo){
    
    if(tipo == 'kilos'){
    
        //Obtenemos los items
        var items = $j('.item-kilos');
        
        //Obtenemos los items confirmacion
        var itemsConfirmacion = $j('.item-confirmacion-kilos'); 
    
    }else if(tipo == 'hectareas'){
        
        //Obtenemos los items
        var items = $j('.item-hectareas');
        
        //Obtenemos los items confirmacion
        var itemsConfirmacion = $j('.item-confirmacion-hectareas'); 
        
    }
    
    if(items.length != itemsConfirmacion.length)
        return;
    
    //Recorremos los items
    for(var i = 0 ; i < items.length ; i++){
        
        var valueItem = items[i].value;
        var valueIC =  itemsConfirmacion[i].value;
        
        if(objeto == itemsConfirmacion[i]){
        
            //Si ambos son iguales, seteamos Exito en el item confirmacion
            if(valueItem == valueIC){
                
                setearEstadoExito(itemsConfirmacion[i]);
                
            }else{
                //Si son distintos seteamos error
                setearEstadoError(itemsConfirmacion[i]);
            
            }
            
            break;
        }
        
    }

}

function disableSelect(id){
    var select = document.getElementById(id);
    select.disabled = true;
    select.setAttribute('data-loading','true');
}

function enableSelect(id){
    var select = document.getElementById(id);
    select.disabled = false;
    select.setAttribute('data-loading','false');
}

function disableSelectByClass(className){
    
    var selects = document.querySelectorAll(className);

    for(var i = 0; i < selects.length ; i++){
        selects[i].disabled = true;
        selects[i].setAttribute('data-loading','true');
    }

}

function enableSelectByClass(className){
    
    var selects = document.querySelectorAll(className);

    for(var i = 0; i < selects.length ; i++){
        selects[i].disabled = false;
        selects[i].setAttribute('data-loading','false');
    }

}

function showMessage(msg,status){
    
    //Eliminamos los posibles estados del cartel de error
    $j('#customMessage').removeClass('alert-success');
    
    //Eliminamos los posibles estados del cartel de error
    $j('#customMessage').removeClass('alert-danger');
    
    //Seteamos el mensaje
    $j('#customMessage > p').html(msg);
    
    //Seteamos el estado dependiento el estatus
    if(status == 'error'){
        $j('#customMessage').addClass('alert-danger');
    }else{
        $j('#customMessage').addClass('alert-success');
    }
    
    //Mostramos el mensaje
    $j('#customMessage').show();
            
}

function hideMessage(){
    $j('#customMessage').hide();
}


function callAjaxSpinner(){
    $j('#ajaxSpinner').modal({});
}

function hideAjaxSpinner(){
    $j('#ajaxSpinner').modal('hide');
}