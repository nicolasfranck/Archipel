//This prototype is provided by the Mozilla foundation and
//is distributed under the MIT license.
//http://www.ibiblio.org/pub/Linux/LICENSES/mit.license
if(!Array.prototype.map) {
        Array.prototype.map= function(mapper, that /*opt*/) {
                var other= new Array(this.length);
                for (var i= 0, n= this.length; i<n; i++)if (i in this)other[i]= mapper.call(that, this[i], i, this);
                return other;
        };

}
if (!Array.prototype.some)
{
  Array.prototype.some = function(fun /*, thisp*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    var thisp = arguments[1];
    for (var i = 0; i < len; i++)
    {
      if (i in this && fun.call(thisp, this[i], i, this))return true;
    }

    return false;
  };
}
if (!Array.prototype.all)
{
  Array.prototype.all = function(fun /*, thisp*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    var thisp = arguments[1];
    for (var i = 0; i < len; i++)
    {
      if (i in this && !fun.call(thisp, this[i], i, this))return false;
    }

    return true;
  };
}
if(!Array.prototype.indexOf){
	Array.prototype.indexOf = function(obj){
		for(var i=0; i<this.length; i++){
	        	if(this[i]==obj)return i;
		}
	        return -1;
	};
}
