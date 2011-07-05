(function($){
	
	$.fn.cart = function(opts){
		
		var send = function(el,action){
			
			var data = {};	
			//vooraleer we iets verzenden, de gebruiker iets laten weten..
			if(typeof on_send == 'function')data=on_send(el,data);
			//verzend data			
			jQuery.extend(data,args);		
			var obj = [];		
			for(var id in messages){				
				obj[obj.length]=messages[id];
			}
			data['obj']=encodeURIComponent(JSON.stringify(obj));		
			data['action'] = action;
			//method
			if(method[0]=='ajax'){
				var ajax={
					type: method[1],  
					url: dest_url,
					data:data,
					dataType:'json',
					success:function(response){		
						if(response.success){													
							if(typeof on_success == 'function')on_success(el,response);							
						}else if(response.err){							
							if(typeof on_error == 'function')on_error(el,response);
						}
					}
				};
				$.ajax(ajax);
			}else{
				var date = new Date();
				var time = date.getTime();
				var c = "<div style='display:hidden'><form id='"+time+"' method='"+method[1]+"' action='"+dest_url+"'>";
				for(key in data){
					c+="<input type='hidden' name='"+key+"' value='"+data[key]+"'/>";
				}
				c+="</form></div>";				
				jQuery('body').append(c);
				jQuery('#'+time).submit();
			}	
						
		};
		
		//default handlers
		var add2messages = function(el){
			var o = {};
			for(i=0;i<attributes.length;i++){				
				o[attributes[i]] = $(el).attr(attributes[i]);								
			}
			messages[$(el).attr('_id')]=o;		
		};
		var remove = function(el){
			delete messages[$(el).attr('_id')];
		};
		var clear = function(){
			messages=[];
		};
		var add_h = function(el,action){
			add2messages(el);
			if(send_type == "instant"){
				send(el,action);
				clear();
			}
		};
		var remove_h = function(el,action){
			add2messages(el);
			if(send_type == "instant"){
				send(el,action);
				clear();
			}
		};

		//options		
		var method = opts.method || ['form','post'];//form:post,form:get,ajax:get,ajax:post
		var on_success = opts.on_success;	
		var on_error = opts.on_error;
		var on_send = opts.on_send;//[optioneel]	
		var attributes = opts.attributes;
		var messages = opts.messages;
		var args = opts.args;//[optioneel]worden niet json geëncodeerd		
		var dest_url=opts.dest_url;	
		var event = opts.event || 'click';	
		var add_handler = opts.add || add_h;
		var remove_handler = opts.remove || remove_h;
		var send_handler = opts.send || send;
		var send_type = opts.send_type || 'instant';
		var default_actions = opts.default_actions || ['insert','remove'];//enkel bij gebruik van send_type 'instant'
		//domelementen die het verzenden activeren, en die daarbij opgeven welke actie moet opgegeven worden
		if(opts.activators){
			
			for(var i = 0;i < opts.activators.length;i++){
					var o = opts.activators[i];
					var selector = o['selector'];
					var a_event = o['event'] || 'click';
					var action = o['action'];
					//belangrijk: data via {} meeleveren, want bindings hebben last van closures!
					$(selector).bind(a_event,{a:action},function(e){					
						send_handler(null,e.data.a);
						e.preventDefault();
					});
			}
		}


		return this.each(function(ev){			
			var $this = $(this);
			
			$this.bind(event,function(e){	
				
				//toevoegen of verwijderen uit de lijst?
				var handler = undefined;								
				if(event == 'click'){	
					var c = "checked";var s = "selected";				
					if((c in $this) || (s in $this)){						
						handler = ($this.attr('checked') || $this.attr('selected')) ? add_handler : remove_handler;
					}else{
						//gewone link:enkel toevoegen
						handler = add_handler;
					}					
				}				
				else if(event == 'change'){										
					handler = ($this.attr('checked') || $this.attr('selected')) ? add_handler:remove_handler;		
				}
				//handler($this);	
				var action = (handler == add_handler)? default_actions[0]:default_actions[1];				
				handler($this,action);
				e.preventDefault();
			});
		});	
		
	};
})( jQuery );

/*
	Afspraak: attribuut '_id' moet uniek zijn

		<domelement _id="unique1" rft_id="rug01:1" item_id="1"></domelement>
		<domelement _id="unique2" rft_id="rug01:1" item_id="2"></domelement>

	Werking: alle attributen die opgegeven zijn via 'args' worden opgehaald uit het element
	en in een associatieve rij gestopt onder hun '_id'.

	vb. messages={
		"unique1":{
			"rft_id":"rug01:1","item_id":"1"
		},
		"unique2":{
			"rft_id":"rug01:1","item_id":"2"
		}
	}	


*/

