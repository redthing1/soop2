module soop.app;

import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.algorithm : min;

import vibrant.d;
import commandr;
import toml;
import typetips;

import soop.web;
import soop.global;
import soop.util;

enum APP_VERSION = "v0.1.0";

void main(string[] args) {
	auto a = new Program("soop", "v0.1.0").summary(
		"minimal bidirectional http server")
		.add(new Argument("publicdir", "public directory"))
		.add(new Option("c", "configfile", "config file to use")
				.full("config-file"))
		.add(new Option("l", "host", "host to listen on").defaultValue("0.0.0.0"))
		.add(new Option("p", "port", "config file to use").defaultValue("8000"))
		.add(new Flag("v", "verbose", "turns on more verbose output").repeating)
		.add(new Flag("q", "quiet", "reduces output verbosity").repeating)
		.parse(args);

	// set up logger
	logger.use_colors = true;
	logger.meta_timestamp = false;
	logger.source = "tla";
	logger.verbosity = (Verbosity.info.to!int
			+ min(a.occurencesOf("verbose"), 2)
			- min(a.occurencesOf("quiet"), 2)
	)
		.to!Verbosity;
	
	auto server_host = no!string;
	auto server_port = no!long;
	auto public_dir = no!string;
	auto upload_dir = no!string;

	// config file, if provided
	if (a.option("configfile")) {
		auto config_doc = parseTOML(std.file.readText(a.option("configfile")));
		auto server_config = TomlConfigHelper.bind!ServerConfig(config_doc, "server");
		
		server_host = toOptional(server_config.host);
		server_port = toOptional(server_config.port);
		public_dir = toOptional(server_config.public_dir);
		upload_dir = toOptional(server_config.upload_dir);
	}

	// cli arg config overrides config file
	if (!server_host.has) server_host = some(a.option("host"));
	if (!server_port.has) server_port = some(a.option("port").to!ushort);
	if (!public_dir.has) public_dir = some(a.arg("publicdir"));
	if (!upload_dir.has) upload_dir = some(a.arg("uploaddir"));

	// copy config to global context
	g_context.public_dir = a.arg("publicdir");
	g_context.upload_dir = upload_dir.get;

	// chdir to data dir
	if (!std.file.exists(g_context.public_dir)) {
		writeln("data directory does not exist");
		return;
	}
	// logger.trace("changing working directory to %s", g_context.public_dir);
	// std.file.chdir(g_context.public_dir);

	logger.info("starting soop %s at http://%s:%s", APP_VERSION, server_host, server_port);

	auto settings = new HTTPServerSettings;
	settings.bindAddresses = [server_host.get];
	settings.port = cast(ushort) server_port.get;
	settings.maxRequestSize = 16_000_000_000;

	auto vib = Vibrant(settings);
	vibrant_web(vib);

	vib.start();

	scope (exit)
		vib.stop();
}
