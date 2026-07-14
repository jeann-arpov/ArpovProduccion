window.AuraController = function(component) {

    return {
        
        setIconName: function(sObjectName,attributeToSave) {
            
            var action = component.get("c.getIconName");
            action.setParams({
                "sObjectName":sObjectName
            });
            action.setCallback(this, function(response) {
                if (response.getState() === "SUCCESS") {
                    component.set(attributeToSave,response.getReturnValue());
                } else {
                    $A.get("e.c:messageHandlerEvent")
                    .setParams({'data':{'response':response}})
                    .fire();
                }
            });
            $A.enqueueAction(action);
            
        },

        setDescribeSObjectResult: function(sObjectName,attributeToSave) {
            return new Promise(function (resolve, reject) {
                var action = component.get("c.getDescribeSObjectResult");
                action.setParams({
                    "sObjectName":sObjectName
                });
                action.setCallback(this, function(response) {
                    if (response.getState() === "SUCCESS") {
                        component.set(attributeToSave,response.getReturnValue());
                    } else {
                        $A.get("e.c:messageHandlerEvent")
                        .setParams({'data':{'response':response}})
                        .fire();
                    }
                });
                $A.enqueueAction(action);
            });
        },

        getLayout: function(sObjectName) {
            return new Promise(function (resolve, reject) {
                var action = component.get("c.getLayout");
                action.setParams({
                    "sObjectName":sObjectName
                });
                action.setCallback(this, function(response) {
                    if (response.getState() === "SUCCESS") {
                        resolve(response.getReturnValue());
                    } else {
                        reject(response);
                        $A.get("e.c:messageHandlerEvent")
                        .setParams({'data':{'response':response}})
                        .fire();
                    }
                });
                $A.enqueueAction(action);
            });
        },
        
    };

}