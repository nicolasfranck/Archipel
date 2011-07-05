(function($){
	
	$.fn.cart = function(opts){
		var action_on = opts.action_on;
		var action_off = opts.action_off;
		var on_success = opts.on_success;	
		var on_error = opts.on_error;
		var on_send = opts.on_send;//[optioneel]	
		var attributes = opts.attributes;		
		var args = opts.args;//[optioneel]worden niet json geëncodeerd		
		var dest_url=opts.dest_url;	
		var event = opts.event || 'click';	
		
		return this.each(function(ev){
			
			var $this = $(this);
			$this.bind(event,function(e){
				var data = {};
				data['obj']={};
				if(typeof on_send == 'function')data=on_send($this,data);				
				for(i=0;i<attributes.length;i++){
					data['obj'][attributes[i]]=$this.attr(attributes[i]);											
				}				
				data['obj']=JSON.stringify(data['obj']);				
				if(args){
					$.extend(data,args);	
				}
				if(event == 'click'){	
					var c = "checked";var s = "selected";				
					if((c in $this) || (s in $this)){						
						data['action']= ($this.attr('checked') || $this.attr('selected')) ? action_on:action_off;
					}else{
						var on = ("on" in $this)? $this.attr('on'):0;
						if(on){
							data['action'] = action_off;					
							$this.attr('on',0);
						}else{
							data['action'] = action_on;					
							$this.attr('on',1);						
						}
					}			
					
				}
				else if(event == 'change'){										
					data['action']= ($this.attr('checked') || $this.attr('selected')) ? action_on:action_off;					
				}
				var ajax={
					type: 'POST',  
					url: dest_url,
					data:data,
					dataType:'json',
					success:function(response){		
											
						if(response.success){													
							if(typeof on_success == 'function')on_success($this,response);							
						}else if(response.err){							
							if(typeof on_error == 'function')on_error($this,response);
						}
					}
				};				
				$.ajax(ajax);								
			});
		});		
	};
})( jQuery );

