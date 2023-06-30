module soop.app;

import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.algorithm : min;

import vibe.d;
import vibrant.d;
import commandr;

import soop.web;
import soop.global;

enum APP_VERSION = "v0.1.0";

void main(string[] args) {
	auto a = new Program("soop", "v0.1.0").summary(
		"minimal bidirectional http server")
		.add(new Argument("datadir", "data directory"))
		.add(new Option("l", "host", "host to listen on").defaultValue("0.0.0.0"))
		.add(new Option("p", "port", "config file to use").defaultValue("8000"))
		.parse(args);

	g_context.data_dir = a.arg("datadir");
	auto server_host = a.option("host");
	auto server_port = a.option("port").to!ushort;

	// set up logger
	logger.use_colors = true;
	logger.meta_timestamp = false;
	logger.source = "tla";

	logger.info("starting soop %s at http://%s:%s", APP_VERSION, server_host, server_port);

	auto settings = new HTTPServerSettings;
	settings.hostName = server_host;
	settings.port = server_port;
	settings.maxRequestSize = 16_000_000_000;

	auto vib = Vibrant(settings);
	vibrant_web(vib);

	// listenHTTP is called automatically
	string[] extra_args;
	runApplication(&extra_args);

	scope (exit)
		vib.Stop();
}
