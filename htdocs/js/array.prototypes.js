//This prototype is provided by the Mozilla foundation and
//is distributed under the MIT license.
//http://www.ibiblio.org/pub/Linux/LICENSES/mit.license
if(typeof Array.prototype.map !== 'function') {
	Array.prototype.map = function(fn) {
		for(i=0, r=[], l = this.length; i < l; r.push(fn(this[i++])));
		return r;
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
