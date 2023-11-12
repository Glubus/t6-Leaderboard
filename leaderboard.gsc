#include maps\mp\gametypes\_hud_util;
#include maps\mp\gametypes_zm\_hud_util;
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\bots\_bot_combat;
#include maps\mp\bots\_bot;
init()
{
    thread connect_db();
    level thread onPlayerConnect();
    level.onkillscore = level.onplayerkilled;
    level.onplayerkilled = ::onplayerkilled;
}

/*
 * Initial connexion to database.
 *
 * @param none.
 * @return none.
*/
connect_db(){
    config = spawnstruct();              
    config.host = "localhost";  /* add the host */
    config.user = "root"; /* add the user to connect */
    config.password = ""; /* add your sql password */
    config.port = ; /* add your sql port */
    config.database = "player";  /* add a database named player */
    mysql::set_config(config);
    createTable();      
    print("[^2Leaderboard^7] ^5Connection established : ^3Host = ^6"+config.host+" ^7/ ^3Database = ^6"+config.database+""); 
}


onPlayerKilled( einflictor, attacker, idamage, smeansofdeath, sweapon, vdir, shitloc, psoffsettime, deathanimduration ) //checked matches cerberus output
{
    thread eloUpdate(attacker,self);
}


/*print(attacker.name);
wait(0.2);
 * Update elo for attacker and player
 *
 * @param attacker killer, player victim.
 * @return void.
*/
eloUpdate(attacker,player){
        /*print("[^2Leaderboard^7] ^5Updating Elo for ^6"+player.name+" and ^6"+attacker.name);*/
        wait(0.4);
        /* Query attacker */
        queryAttacker = mysql::prepared_statement("select * from `players` where guid=(?) and name=(?)", attacker.guid, attacker.name);
        queryAttacker waittill("done", resultattacker, error);
        wait(0.2);
        /* Query player */
        queryPlayer=mysql::prepared_statement("select * from `players` where guid=(?) and name=(?)", player.guid, player.name);
        queryPlayer waittill("done",resultplayer);
        wait(0.2);
        /* Calculate Elo */
        factor = 15;
        expectedScoreA = 1 / (1 + (Pow(10, ( resultplayer[0]["point"] - resultattacker[0]["point"]) / 400)) );
        expectedScoreB = 1 / (1 + (Pow(10, ( resultattacker[0]["point"] - resultplayer[0]["point"]) / 400)) );
        newRatingA = resultattacker[0]["point"] + 1 +(factor * ( 1 - expectedScoreA ) );
        newRatingB = resultplayer[0]["point"] - 1 +  (factor * ( 0 - expectedScoreB ) );    
        
        /* Send update to player about their elo */
        if(player.pers["isBot"]==false){
            player tell("Rating : "+newRatingB+" ("+(newRatingB-resultplayer[0]["point"])+"]");
        }
        if(attacker.pers["isBot"]==false){
            attacker tell("Rating : "+newRatingA+" (+"+(newRatingA-resultattacker[0]["point"])+")");   
        }

        /* Refresh player tag */
        thread playertag(attacker, int(newRatingA));
        thread playertag(player, int(newRatingB));

        /* Update Database */
        querA = mysql::prepared_statement("update `players` set point=(?), kills=(?) where guid=(?) and name=(?)", newRatingA, resultattacker[0]["kills"]+1,attacker.guid, attacker.name);
        querA waittill("done", result);
        querB = mysql::prepared_statement("update `players` set point=(?), death=(?) where guid=(?) and name=(?)", newRatingB, resultplayer[0]["death"]+1, player.guid, player.name);
        querB waittill("done", result);   

}

onPlayerConnect() {
    for(;;){
    level endon("disconnect");
    level waittill("connected", player);
    print("[^2Leaderboard^7] ^5Player connected : ^3Guid ^6["+player.guid+"] ^7/ ^3Name ^6["+player.name+"]");
    wait(0.2);
    query = mysql::prepared_statement("select * from `players` where guid=(?) and name=(?)", player.guid,player.name); 
    query waittill("done", result); 
    wait(0.2);
    if (result.size == 0)
    {
        addToDB(player);
    }
    query = mysql::prepared_statement("select guid, name, point from `players` where guid=(?) and name=(?)", player.guid,player.name);
    query waittill("done", result, error);
    player thread playertag(player, result[0]["point"]);
    player thread playerrank(player,result);
    if (player.pers["isBot"]==false){
            player iprintlnbold("Hello "+result[0]["name"]+" with "+result[0]["point"]+" point."); 

            print("[^2Leaderboard^7] Message to player send : ^3Guid ^6["+result[0]["guid"]+"] ^7/ ^3Name ^6["+result[0]["name"]+"]");
            thread addpointoverlay(player);
        }
    }   
}

playerrank(player,result){
    query = mysql::prepared_statement("SELECT * FROM (SELECT *,RANK() OVER (ORDER BY point DESC) AS `rank` FROM players) AS ranked_players WHERE guid=(?) and name=(?);",player.guid,player.name);
    query waittill("done", resultB);
    query = mysql::prepared_statement("select count(*) as count from players;");   
    query waittill("done", resultA);  
    say("[^2Leaderboard^7] ^5Hello ^6"+result[0]["name"]+" with "+result[0]["point"]+" ^5point. Ranked : ^2"+resultB[0]["rank"]+"^7/^5"+resultA[0]["count"]);
}

addToDB(player){
        query = mysql::prepared_statement("insert into `players` (`guid`,`name`) values (?, ?)", player.guid, player.name);
        query waittill("done", result,affected_rows);
        print("[^2Leaderboard^7] ^5Player added in database : ^3Guid ^6["+player.guid+"] ^7/ ^3Name ^6["+player.name+"]");  
}

addpointoverlay(player)
{
	level endon("end_game");
	player endon("disconnect");
    print("[^2Leaderboard^7] ^5Overlay for ^6"+player.name+" ^5setup.");
    player.textTest = player thread CreateHudText("Your point : "+result[0]["point"], "objective", 1.5, "LEFT", "CENTER", "RIGHT", 100);
    for(;;)
	{
        query = mysql::prepared_statement("select guid, name, point from `players` where guid=(?)", player.guid);
        query waittill("done", result);
        player.textTest setText("Your point : "+result[0]["point"]);
		wait 3;
	}

}

playertag(player,point){
    wait(0.2);
    player setClantag(""+point);
}


/* added from mapvote script all right to blob*/
CreateHudText(text, font, fontScale, relativeToX, relativeToY, relativeX, relativeY, isServer, value)
{
    hudText = "";

    if (IsDefined(isServer) && isServer)
    {
        hudText = CreateServerFontString( font, fontScale );
    }
    else
    {
        hudText = CreateFontString( font, fontScale );
    }

    if (IsDefined(value))
    {
        hudText.label = text;
        hudText SetValue(value);
    }
    else
    {
        hudText SetText(text);
    }

    hudText SetPoint(relativeToX, relativeToY, relativeX, relativeY);
    
    hudText.hideWhenInMenu = 1;
    hudText.glowAlpha = 0;

    return hudText; 
}

createTable(){
    query = mysql::prepared_statement("CREATE TABLE  IF NOT EXISTS `player`.`players` (`guid` INT NOT NULL , `name` VARCHAR(100) NOT NULL, `kills` INT NOT NULL DEFAULT '0' , `death` INT NOT NULL DEFAULT '0' , `point` INT NOT NULL DEFAULT '1000' ) ENGINE = InnoDB DEFAULT CHARSET=latin1;");
    query waittill("done", result);
    }
