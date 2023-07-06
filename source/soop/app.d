module soop.app;

import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.algorithm : min;

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
		.add(new Flag("v", "verbose", "turns on more verbose output").repeating)
		.add(new Flag("q", "quiet", "reduces output verbosity").repeating)
		.parse(args);

	g_context.data_dir = a.arg("datadir");
	auto server_host = a.option("host");
	auto server_port = a.option("port").to!ushort;

	// set up logger
	logger.use_colors = true;
	logger.meta_timestamp = false;
	logger.source = "tla";
	logger.verbosity = (Verbosity.info.to!int
			+ min(a.occurencesOf("verbose"), 2)
			- min(a.occurencesOf("quiet"), 2)
	)
		.to!Verbosity;

	// chdir to data dir
	if (!std.file.exists(g_context.data_dir)) {
		writeln("data directory does not exist");
		return;
	}
	logger.trace("changing working directory to %s", g_context.data_dir);
	std.file.chdir(g_context.data_dir);

	logger.info("starting soop %s at http://%s:%s", APP_VERSION, server_host, server_port);

	auto settings = new HTTPServerSettings;
	settings.bindAddresses = [server_host];
	settings.port = server_port;
	settings.maxRequestSize = 16_000_000_000;

	auto vib = Vibrant(settings);
	vibrant_web(vib);

	vib.start();

	scope (exit)
		vib.stop();
}
