const express = require("express");
const app = express();

const cheerio = require('cheerio');
const request = require('request');
const url = require('url');

const portti = process.env.PORT || 8080;

const iDays = 90;
const ParseThese =
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
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Mannpower&actualsort=trend&p=1&days=",			"MANNPOWER"],
	["http://steamcommunity.com/workshop/browse/?appid=440&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Mann+vs.+Machine&actualsort=trend&p=1&days=",	"MVM"]
];

app.use((req, res, next) => {
	res.header("Access-Control-Allow-Origin", "*");
	res.header("Access-Control-Allow-Methods", "GET");
	res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept")
	next();
});

var mapObjArray = [];

//GET maps
app.get("/", (req, res) => {
	
	if(mapObjArray.length < 420)
		return res.end();

	//Muodosta KeyValues responssi
	let response = '"WorkshopData"\n{\n';

	mapObjArray.forEach(mapObj => {
		
		response += '    "section"\n    {\n';
		
		for (var key in mapObj) 
		{
			if (mapObj.hasOwnProperty(key)) 
			{
				var value = mapObj[key];
				response += '        "' + key + '"    "' + value + '"\n';
			}
		}
		
		response += "    }\n";
	});

	response += "}\n";
	///////////////////////////

	res.end(response);
});

function ParseAll()
{
	mapObjArray = [];

	ParseThese.forEach(workshopItem => {
		ScrapeMapWorkshopUrl(workshopItem);
	});
};

function ScrapeMapWorkshopUrl(workshopItem)
{
	var gamemode = workshopItem[1];
	
	console.log("Scraping TF2 Map Workshop Data for " + gamemode + " for " + iDays + " days...");
	
	request(workshopItem[0], (error, response, html) =>
	{
		if(error || response.statusCode != 200){
			console.error(`Failed to parse "${gamemode}" error ${error} status ${response.statusCode}`);
			return;
		}

		var $ = cheerio.load(html);
		$('div[class*="workshopItem "]').each(function(i, element)
		{
			let link = $(this).find("a").attr('href');
			let id = url.parse(link).search.replace("?id=", "").replace("&searchtext=", "");
			
			let ratingimageurl = $(this).find('.fileRating').attr('src');
			
			let rating = "0";
			if(StringContains(ratingimageurl, "5-star"))      rating = "5";
			else if(StringContains(ratingimageurl, "4-star")) rating = "4";
			else if(StringContains(ratingimageurl, "3-star")) rating = "3";
			else if(StringContains(ratingimageurl, "2-star")) rating = "2";
			else if(StringContains(ratingimageurl, "1-star")) rating = "1";
			
			let maker = $(this).find('.workshopItemAuthorName').find("a").text().replace(/"/g, "'");
			let mapname = $(this).find(".workshopItemTitle").text();
			
			let mapDataObJ = {
				"id": id,
				"rating": rating,
				"maker": maker,
				"mapname": mapname,
				"gamemode": gamemode,
				"time_created": 0,
				"time_updated": 0
			}

			mapObjArray.push(mapDataObJ);
		});
	}).on('complete', (response) => {
		let IDs = [];

		mapObjArray.forEach(mapItem => {
			IDs.push(mapItem.id);
		});

		var requestData = {
			"format": 'json',
			"itemcount": mapObjArray.length,
			"publishedfileids": IDs
		}

		request.post("https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/", {form: requestData}, (error, resp, body) =>
		{
			if(error || response.statusCode != 200){
				console.error(`GetPublishedFileDetails: Failed to parse error ${error} status ${resp.statusCode}`);
				return;
			}

			var data = JSON.parse(body);

			if (!data || !data.response || !data.response.publishedfiledetails) {
				console.error('GetPublishedFileDetails: No data in response');
				return;
			}

			//Loop response
			data.response.publishedfiledetails.forEach(item => {

				//Assocciate and append response data to scraped data.
				mapObjArray.forEach(map => {
					if(map.id != item.publishedfileid)
						return;

					map.time_created = item.time_created;
					map.time_updated = item.time_updated;
				});
			});
		})
	});
}

function StringContains(string, text)
{
	return (string.indexOf(text) > -1);
};

app.listen(portti, () => {
	console.log("Palvelin käynnistyi porttiin " + portti);

	var dayInMilliseconds = 1000 * 60 * 60 * 24;
	ParseAll();

	setInterval(function() { ParseAll() }, dayInMilliseconds);
});