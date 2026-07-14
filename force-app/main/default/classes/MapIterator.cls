/**
* @author Maximo Martinez
* @date 17/02/2020
* @description Clase usada para iterar sobre una 
*/
public with sharing class MapIterator implements Iterator<Map<String,Object>>, Iterable<Map<String,Object>>{

    private List<Map<String,Object>> maps;

    public MapIterator(List<Map<String,Object>> maps){
        this.maps = maps;
    }

    public Boolean hasNext(){
        return !this.maps.isEmpty();
    }

    public Map<String,Object> next(){
        return this.maps.remove(0);
    }

    public Iterator<Map<String,Object>> Iterator(){
        return this;
    }

}