function setLanguage(lang){
	var vars = getUrlVars();
	var host = location.host;//hostname+":"+port (indien port expliciet is opgegeven)
	var path = location.pathname;
	var protocol = location.protocol;
	var hash = location.hash;
	vars["language"]=lang || "nl";
	var params = [];
	for(var key in vars){
		if(typeof vars[key] == "function")continue;
		params.push(key+"="+vars[key]);
	}
	var url = protocol+"//"+host+path+"?"+params.join('&')+hash;
	window.location.href = url;
}
