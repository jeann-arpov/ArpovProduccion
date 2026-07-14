app.factory('RemoteAction',['$q', '$rootScope', function($q, $rootScope) {
                       
    return function(remoteAction,data) {
        
        var deferred = $q.defer();
        
        Visualforce.remoting.Manager.invokeAction(
            remoteAction,
            data,
            function(result, event){
                $rootScope.$apply(function(){
                    deferred.resolve(result);
                });
            }
        );

        return deferred.promise;
    
    }

}]);