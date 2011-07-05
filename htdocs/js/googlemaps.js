var map;
var info;
var geocoder;
var areas = ['political','locality'];
function initialize() {
        geocoder = new google.maps.Geocoder();
        var latlng = new google.maps.LatLng(50.79, 4.27);
        var myOptions = {
                zoom: 8,
                center: latlng,
                mapTypeId: google.maps.MapTypeId.ROADMAP
        };
        map = new google.maps.Map(document.getElementById("map_canvas"),myOptions);
        info = new google.maps.InfoWindow({
                position:latlng,
                map:map
        });
        google.maps.event.addListener(map,'click',function(googleEvent){
                if(geocoder){
                        var ll = googleEvent.latLng;
                        geocoder.geocode({"latLng":ll},function(results,status){
                                if(status == google.maps.GeocoderStatus.OK){
                                        var hash = {
                                                "country":undefined,
                                                "areas":[]
                                        };
                                        for(var i=0;i<results.length;i++){
                                                for(var j = 0;j<results[i].address_components.length;j++){
                                                        var country_index = results[i].address_components[j].types.indexOf('country');
                                                        if(country_index != -1)hash['country']=results[i].address_components[j].short_name;
                                                        var found = areas.all(function(a){
                                                                return results[i].address_components[j].types.indexOf(a) != -1;
                                                        });
                                                        if(found){
                                                                hash['areas'][results[i].address_components[j].long_name] = 1;
                                                        }
                                                }
                                        }
                                        if(hash['country'] != 'BE'){
                                                alert(only_belgium);
                                                return;
                                        }
                                        var places = [];
                                        for(var key in hash['areas']){
                                                if((typeof hash['areas'][key]) != 'function')places.push(key);
                                        }
                                        var links = places.map(function(x){
                                                return "<a href=\""+url+x+"\">"+x+"</a>";
                                        });
                                        var content = no_places_found;
                                        if(links.length > 0){
                                                content = search_for+":<br/>"+links.join('<br/>')
                                        }
                                        info.setPosition(googleEvent.latLng);
                                        info.setContent(content);
                                        info.open(map);
                                }

                        });
                }
        });
}
