jQuery(document).ready(function(){
	var options = {
                "flashplayer": flashplayer,
                "width": "400",
                "height": "300",
                "provider": streaming_provider,
                "file": url,
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
        jwplayer("player").setup(options);
});
function getPlayer(){
        return player;
}
