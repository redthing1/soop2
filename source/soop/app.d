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

enum APP_NAME = "soop2";
enum APP_VERSION = "v0.4.0";

void main(string[] args) {
	auto a = new Program(APP_NAME, APP_VERSION).summary(
		"the based http fileserver")
		.add(new Argument("publicdir", "public directory"))
		.add(new Option("c", "configfile", "config file to use")
				.full("config-file"))
		.add(new Option("l", "host", "host to listen on").defaultValue("0.0.0.0"))
		.add(new Option("p", "port", "config file to use").defaultValue("8000"))
		.add(new Flag("u", "enableupload", "enable file uploads"))
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
	auto enable_upload = no!bool;

	// config file, if provided
	auto server_config = ServerConfig();
	auto security_config = SecurityConfig();
	auto listing_config = ListingConfig();
	auto upload_config = UploadConfig();
	if (a.option("configfile")) {
		auto config_path = a.option("configfile");
		logger.info("using config file %s", config_path);
		auto config_doc = parseTOML(std.file.readText(config_path));
		TomlConfigHelper.bind!ServerConfig(server_config, config_doc, "server");

		server_host = toOptional(server_config.host);
		server_port = toOptional(server_config.port);
		public_dir = toOptional(server_config.public_dir);
		upload_dir = toOptional(server_config.upload_dir);
		enable_upload = toOptional(server_config.enable_upload);

		TomlConfigHelper.bind!SecurityConfig(security_config, config_doc, "security");
		TomlConfigHelper.bind!ListingConfig(listing_config, config_doc, "listing");
		TomlConfigHelper.bind!UploadConfig(upload_config, config_doc, "upload");
	}

	// cli arg config overrides config file
	if (a.option("host"))
		server_host = some(a.option("host"));
	if (a.option("port"))
		server_port = some(a.option("port").to!ushort);
	if (a.arg("publicdir"))
		public_dir = some(a.arg("publicdir"));
	if (!upload_dir.has)
		upload_dir = public_dir; // default to public dir
	if (!enable_upload.has)
		enable_upload = some(a.flag("enableupload"));

	// default host and port, if still not set
	if (!server_host.has)
		server_host = "0.0.0.0";
	if (!server_port.has)
		server_port = 8000;

	// copy config to global context
	g_context.public_dir = public_dir.get;
	g_context.upload_dir = upload_dir.get;
	g_context.enable_upload = enable_upload.get;

	g_context.security_config = security_config;
	g_context.listing_config = listing_config;
	g_context.upload_config = upload_config;

	// chdir to data dir
	if (!std.file.exists(g_context.public_dir)) {
		writeln("data directory does not exist");
		return;
	}

	// logger.trace("changing working directory to %s", g_context.public_dir);
	// std.file.chdir(g_context.public_dir);

	logger.info("starting %s %s at http://%s:%s", APP_NAME, APP_VERSION, server_host, server_port);

	auto settings = new HTTPServerSettings;
	settings.bindAddresses = [server_host.get];
	settings.port = cast(ushort) server_port.get;
	settings.maxRequestSize = g_context.upload_config.max_request_size;

	logger.dbg("public dir: %s", g_context.public_dir);
	logger.dbg("upload dir: %s", g_context.upload_dir);
	logger.dbg("max request size: %s", settings.maxRequestSize);
	// logger.dbg("security config: %s", security_config);
	logger.dbg("security config: %s", security_config);
	logger.dbg("listing config: %s", listing_config);
	logger.dbg("upload config: %s", upload_config);

	if (g_context.enable_upload) {
		logger.warn("file uploads are enabled and will be saved to %s", g_context.upload_dir);
	}

	auto vib = Vibrant(settings);
	vibrant_web(vib);

	vib.start();

	scope (exit)
		vib.stop();
}
