var cheerio = require('cheerio');
var request = require('request');
var url = require('url');
var http = require('http');

var listenport = 9876;
var myDataArray = [];
var HTMLString = "";

var iDays = 90;
var parsingIndex = 0;
var ParseThese =
[
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B0%5D=Capture+the+Flag&actualsort=trend&p=1&days=",	"CTF"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B0%5D=Control+Point&actualsort=trend&p=1&days=",		"CP"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B0%5D=Payload&actualsort=trend&p=1&days=",			"PL"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B0%5D=Payload+Race&actualsort=trend&p=1&days=",		"PLR"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B0%5D=Arena&actualsort=trend&p=1&days=",				"ARENA"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B0%5D=King+of+the+Hill&actualsort=trend&p=1&days=",	"KOTH"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B0%5D=Attack+%2F+Defense&actualsort=trend&p=1&days=",	"AD"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Special+Delivery&actualsort=trend&p=1&days=",	"SD"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Robot+Destruction&actualsort=trend&p=1&days=",	"RD"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Specialty&actualsort=trend&p=1&days=",			"SPECIALITY"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=PASS+Time&actualsort=trend&p=1&days=",			"PASS"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Medieval&actualsort=trend&p=1&days=",			"MEDIEVAL"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Mannpower&actualsort=trend&p=1&days=",			"MANNPOWER"]
];

http.get({'host': 'api.ipify.org', 'port': 80, 'path': '/'}, function(resp) 
{
	resp.on('data', function(ip) 
	{
		console.log("Server running on " + ip + ":" + listenport);
		
		FUCK();
		setInterval(function()
		{
			FUCK();
		}, 600000);
	});
});

function FUCK()
{
	parsingIndex = 0;
	
	while (myDataArray.length > 0)
		myDataArray.pop();
	
	while (parsingIndex < ParseThese.length)
	{
		ScrapeMapWorkshopUrl(ParseThese[parsingIndex][0] + iDays);
		parsingIndex++;
	}
}

http.createServer(function (req, res) 
{
	res.writeHead(200, {'Content-Type': 'application/json; charset=utf-8'});
	res.end(HTMLString);
}).listen(listenport);

function ScrapeMapWorkshopUrl(sivu)
{
	var gamemode = ParseThese[parsingIndex][1];
	
	console.log("Scraping TF2 Map Workshop Data for " + gamemode + " for " + iDays + " days...");
	
	request(sivu, function(error, response, html)
	{
		if(!error && response.statusCode == 200)
		{
			var $ = cheerio.load(html);
			$('div[class*="workshopItem "]').each(function(i, element)
			{
				var link = $(this).find("a").attr('href');
				var id = url.parse(link).search.replace("?id=", "").replace("&searchtext=", "");
				
				var ratingimageurl = $(this).find('.fileRating').attr('src');
				var rating = "";
				if(StringContains(ratingimageurl, "5-star"))
					rating = "5";
				else if(StringContains(ratingimageurl, "4-star"))
					rating = "4";
				else if(StringContains(ratingimageurl, "3-star"))
					rating = "3";
				else if(StringContains(ratingimageurl, "2-star"))
					rating = "2";
				else if(StringContains(ratingimageurl, "1-star"))
					rating = "1";
				else
					rating = "0";
				
				var maker = $(this).find('.workshopItemAuthorName').find("a").text();
				var mapname = $(this).find(".workshopItemTitle").text();
				
				maker = maker.replace(/"/g, "'");
				
				var myData = new Object();
				myData.id = id;
				myData.rating = rating;
				myData.maker = maker;
				myData.mapname = mapname;
				myData.gamemode = gamemode;

				myDataArray.push(myData);
			});

			HTMLString = '"WorkshopData"\n{\n';
			for (var i = 0, l = myDataArray.length; i < l; i++) 
			{
				HTMLString += '    "section"\n    {\n';
				
				var obj = myDataArray[i];
				for (var key in obj) 
				{
					if (obj.hasOwnProperty(key)) 
					{
					//	console.log(key + '"    "' + obj[key]);
						var value = obj[key];
						HTMLString += '        "' + key + '"    "' + value + '"\n';
					}
				}
				
				HTMLString += "    }\n";
			}
			HTMLString += "}\n";
		}
	});
}

function StringContains(string, text)
{
	if(string.indexOf(text) > -1) 
	{
		return true;
	}
	
	return false;
}