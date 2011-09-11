jQuery(document).ready(function(){
	var default_options = {
                "width": "400",
                "height": "300",
                /*
                        controlbar wordt enkel getoond in de volgende situaties: gebruiker beweegt met muis over de video
                        andere situaties: 
                                - video speelt (geen controlbar)
                                - video is gepauzeer of gestopt, of nog niet begonnen. Enkel thumbnail wordt getoond, met "play"-button erboven
                        idlehide:false -> wanneer de video gepauzeerd/gestopt is, dan blijft de controlbar staan

                */
                "controlbar.position": "over",
                "controlbar.idlehide": true,
                /*
                        play-icon en andere iconen niet toelaten
                */
                "icons": false,
                /*
                        niet automatisch starten
                */
                "autostart": true,
                /*
                        JW-Logo verbergen -> lukt enkel voor licensie-kopieën!
                "logo.hide":true,
                "logo.file": 'http://localhost/grim/images/icons/logo-ugent.png'
                */
                "screencolor": "black"
                /*
                        Javascript API
                */
        };
	jQuery.extend(default_options,options);
        jwplayer("player").setup(default_options);
});
