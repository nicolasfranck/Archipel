function getUrlVars(){
	var vars = [], hash;
	var index = location.search.indexOf('?');
	if(index != -1){
		var hashes = location.search.substr(index+1).split('&');
		for(var i = 0; i < hashes.length; i++){
			hash = hashes[i].split('=');
			vars[hash[0]] = hash[1];
		}
	}
	return vars;
}
