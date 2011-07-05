(function($){
	
	$.fn.cart = function(opts){
		
		var on_success = opts.on_success;	
		var on_send = opts.on_send;//[optioneel]	
		var attributes = opts.attributes;	
		var id_field = opts.id_field || 'id';
		var args = opts.args;//[optioneel]worden niet json geëncodeerd		
		var dest_url=opts.dest_url;	
		var event = opts.event || 'click';	
		
		return this.each(function(ev){
			
			var $this = $(this);
			$this.bind(event,function(e){
				if(typeof on_send == 'function')on_send($this);
				var data = {};
				data['obj']={};
				for(i=0;i<attributes.length;i++){
					data['obj'][attributes[i]]=$this.attr(attributes[i]);											
				}				
				data['obj']=JSON.stringify(data['obj']);				
				if(args){
					$.extend(data,args);	
				}
				if(event == 'click')data['action'] = "insert";					
				else if(event == 'change'){					
					data['action']= ($this.attr('checked') || $this.attr('selected')) ? 'insert':'remove';
				}
				var ajax={
					type: 'POST',  
					url: dest_url,
					data:data,
					dataType:'json',
					success:function(response){						
						if(response.success){													
							if(typeof on_success == 'function')on_success($this,response);							
						}
					}
				};				
				$.ajax(ajax);								
			});
		});		
	};
})( jQuery );

